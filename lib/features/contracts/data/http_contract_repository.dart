import 'dart:convert';
import 'dart:io' show HttpHeaders;
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../core/api/api_client.dart';
import '../../../core/api/api_failure.dart';
import '../../auth/data/authenticated_client.dart';
import '../../auth/domain/auth_session_store.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_failure.dart';
import '../domain/contract_repository.dart';
import '../domain/student_contract.dart';

/// The student contract list (Issues #294, #300):
///
///     GET /me/contracts
///       -> {"contracts": [{id, contract_number, status, enrollment_id,
///           course_id, course {id, slug, title {mn, en}, level},
///           cohort {id, name, start_date, end_date}, created_at,
///           signed_at, cancelled_at, can_view, can_sign, is_current,
///           document_url}, ...]}
///
/// The item shape is the backend's own (`ai-academy-backend`
/// `docs/e_contract_api_v1.md`, commit `208e1c9`), **not observed live**:
/// the only production response seen is `{"contracts": []}` (Adult student).
/// The list is newest first. Calling it is not side-effect free on the
/// backend: it creates `pending` rows for the student's own eligible
/// enrollments (`core.sync()`), by design.
///
/// **The envelope is required, the fields are lenient.** A missing
/// `contracts` array, or an entry that is not an object, is the server's
/// fault ([ContractFailureKind.server]). Inside an entry, a missing or
/// mistyped field reads as null (false for the flags) — see
/// [StudentContract] — so the list's length stays the server's.
///
/// Detail, `/sign` and `/download` (Issue #302) follow the same
/// backend-source shapes — see [contractDetailFrom] and
/// [contractFailureFor] — and are not observed live either; no screen calls
/// them yet. `/preview` (raw PDF bytes) has no client.
///
/// Sent through [AuthenticatedClient.instance], so an expired access token is
/// renewed and the request retried once; a 401 that survives that ends the
/// session here too, as every authenticated repository does.
class HttpContractRepository implements ContractRepository {
  HttpContractRepository({
    http.Client? client,
    Uri? baseUrl,
    AuthSessionStore? sessionStore,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? AuthenticatedClient.instance,
       _baseUrl = baseUrl ?? Uri.parse(defaultBaseUrl),
       _sessionStore = sessionStore ?? AuthSessionStore.instance;

  static const String defaultBaseUrl = 'https://api.ai-academy.asia';

  final http.Client _client;
  final Uri _baseUrl;
  final AuthSessionStore _sessionStore;
  final Duration timeout;

  @override
  Future<List<StudentContract>> getContracts() async {
    final decoded = _object(
      await _send(
        (headers) => getRaw(
          client: _client,
          url: _baseUrl.resolve('/me/contracts'),
          headers: headers,
          timeout: timeout,
        ),
      ),
    );
    final items = decoded['contracts'];
    if (items is! List) {
      throw const ContractFailure(
        ContractFailureKind.server,
        detail: 'contracts: expected a list',
      );
    }
    final contracts = <StudentContract>[];
    for (final (i, item) in items.indexed) {
      if (item is! Map<String, dynamic>) {
        throw ContractFailure(
          ContractFailureKind.server,
          detail: 'contracts[$i]: not an object',
        );
      }
      contracts.add(contractFrom(item));
    }
    return contracts;
  }

  /// See [contractDetailFrom]. Like the list, this call creates `pending`
  /// rows on the backend (`core.sync()`), by design.
  @override
  Future<ContractDetail> getContractDetail(String contractId) async =>
      contractDetailFrom(
        _object(
          await _send(
            (headers) => getRaw(
              client: _client,
              url: _contractUrl(contractId),
              headers: headers,
              timeout: timeout,
            ),
          ),
        ),
      );

  /// Sends `{"form": {…all eleven fields}, "agreed": …, "signature": …}`
  /// exactly; the success body is the detail shape, now `signed`.
  @override
  Future<ContractDetail> signContract(
    String contractId, {
    required ContractForm form,
    required bool agreed,
    required String signature,
  }) async => contractDetailFrom(
    _object(
      await _send(
        (headers) => postJsonRaw(
          client: _client,
          url: _contractUrl(contractId, '/sign'),
          headers: headers,
          body: {
            'form': form.toJson(),
            'agreed': agreed,
            'signature': signature,
          },
          timeout: timeout,
        ),
      ),
    ),
  );

  /// `{url, expires_at}`: `url` must be an http(s) link and `expires_at` a
  /// timestamp, or the body is the server's fault.
  @override
  Future<ContractDownload> getContractDownload(String contractId) async {
    final decoded = _object(
      await _send(
        (headers) => getRaw(
          client: _client,
          url: _contractUrl(contractId, '/download'),
          headers: headers,
          timeout: timeout,
        ),
      ),
    );
    final rawUrl = decoded['url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl) : null;
    if (url == null || !(url.isScheme('https') || url.isScheme('http'))) {
      throw const ContractFailure(
        ContractFailureKind.server,
        detail: 'download.url: expected an http(s) link',
      );
    }
    final expiresAt = _time(decoded['expires_at']);
    if (expiresAt == null) {
      throw const ContractFailure(
        ContractFailureKind.server,
        detail: 'download.expires_at: expected a timestamp',
      );
    }
    return ContractDownload(url: url, expiresAt: expiresAt);
  }

  /// `POST /me/contracts/{contract_id}/preview` with `{"form": {…}}` — the
  /// course's contract PDF filled with [form], unsigned. The backend saves
  /// nothing (`student.preview`), and answers raw `application/pdf`; a
  /// signed or cancelled contract is `409`. See [contractPdfFrom] for what a
  /// success must be.
  @override
  Future<Uint8List> getContractPreview(
    String contractId, {
    required ContractForm form,
  }) async => contractPdfFrom(
    await _sendRaw(
      (headers) => postJsonRaw(
        client: _client,
        url: _contractUrl(contractId, '/preview'),
        headers: {...headers, HttpHeaders.acceptHeader: 'application/pdf'},
        body: {'form': form.toJson()},
        timeout: timeout,
      ),
    ),
  );

  Uri _contractUrl(String contractId, [String suffix = '']) => _baseUrl.resolve(
    '/me/contracts/${Uri.encodeComponent(contractId)}$suffix',
  );

  /// [_sendRaw]'s body, for the JSON calls.
  Future<String> _send(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async => (await _sendRaw(request)).body;

  /// Sends an authenticated request and answers its successful response, or
  /// throws the [ContractFailure] its status and `error` code mean — see
  /// [contractFailureFor].
  Future<http.Response> _sendRaw(
    Future<http.Response> Function(Map<String, String> headers) request,
  ) async {
    if (!_sessionStore.isSignedIn || _sessionStore.isExpired()) {
      throw const ContractFailure(
        ContractFailureKind.sessionExpired,
        detail: 'no usable session',
      );
    }

    final http.Response response;
    try {
      response = await request(_sessionStore.authorizationHeader);
    } on ApiFailure catch (failure) {
      // The transport throws only for a request that never completed.
      throw ContractFailure(
        ContractFailureKind.network,
        detail: failure.detail,
      );
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) return response;
    if (status == 401) {
      // A token the backend refused even after renewal: forget it.
      _sessionStore.clear();
      throw const ContractFailure(
        ContractFailureKind.sessionExpired,
        detail: 'HTTP 401',
      );
    }
    throw contractFailureFor(status, response.body);
  }
}

/// A successful preview's PDF: the response must say `application/pdf`
/// (parameters such as `; charset` ignored) and its body must start with the
/// PDF signature `%PDF`. Anything else is the server's fault. The failure
/// names the content type at most — never the bytes. Public so it can be
/// tested on its own.
Uint8List contractPdfFrom(http.Response response) {
  final contentType = response.headers['content-type'];
  final mediaType = contentType?.split(';').first.trim().toLowerCase();
  if (mediaType != 'application/pdf') {
    throw ContractFailure(
      ContractFailureKind.server,
      detail: 'preview: expected application/pdf, got ${mediaType ?? 'none'}',
    );
  }
  final bytes = response.bodyBytes;
  if (bytes.length < _pdfMagic.length ||
      !_pdfMagic.indexed.every((entry) => bytes[entry.$1] == entry.$2)) {
    throw const ContractFailure(
      ContractFailureKind.server,
      detail: 'preview: the body is not a PDF',
    );
  }
  return bytes;
}

/// `%PDF`.
const List<int> _pdfMagic = [0x25, 0x50, 0x44, 0x46];

/// The failure a non-2xx, non-401 answer means. The body's `error` code
/// decides when it is one the contract service documents *for that status*;
/// otherwise the status alone does, as before (#294): 5xx is
/// [ContractFailureKind.server], anything else
/// [ContractFailureKind.unexpected]. For `invalid_fields` the body's `fields`
/// map becomes [ContractFailure.fieldErrors]. Public so it can be tested on
/// its own.
ContractFailure contractFailureFor(int status, String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    decoded = null;
  }
  final json = decoded is Map<String, dynamic> ? decoded : null;
  final code = json?['error'];
  final detail = 'HTTP $status${code is String ? ' $code' : ''}';

  final kind = switch ((status, code)) {
    (400, 'invalid_fields') => ContractFailureKind.invalidFields,
    (400, 'agreement_required') => ContractFailureKind.agreementRequired,
    (400, 'signature_required') => ContractFailureKind.signatureRequired,
    (400, 'invalid_signature') => ContractFailureKind.invalidSignature,
    (400, 'empty_signature') => ContractFailureKind.emptySignature,
    (413, 'signature_too_large') => ContractFailureKind.signatureTooLarge,
    (403, 'forbidden') => ContractFailureKind.forbidden,
    (404, 'contract_not_found') => ContractFailureKind.contractNotFound,
    (409, 'already_signed') => ContractFailureKind.alreadySigned,
    (409, 'contract_cancelled') => ContractFailureKind.contractCancelled,
    (409, 'contract_template_missing') => ContractFailureKind.templateMissing,
    (409, 'contract_template_invalid') => ContractFailureKind.templateInvalid,
    (409, 'not_signed') => ContractFailureKind.notSigned,
    (502, 'storage_error') => ContractFailureKind.storageError,
    _ when status >= 500 => ContractFailureKind.server,
    _ => ContractFailureKind.unexpected,
  };

  final fields = json?['fields'];
  return ContractFailure(
    kind,
    detail: detail,
    fieldErrors:
        kind == ContractFailureKind.invalidFields &&
            fields is Map<String, dynamic>
        ? {
            for (final MapEntry(:key, :value) in fields.entries)
              key: ContractFieldReason.fromApi(value),
          }
        : const {},
  );
}

/// The detail shape (`student._detail`): the summary, read like a list item,
/// and the four parts a signing screen needs — each required, with its
/// documented types. Public so the mapping can be tested on its own.
ContractDetail contractDetailFrom(Map<String, dynamic> json) {
  final form = _requireObject(json, 'form');
  final rules = _requireObject(json, 'rules');
  final finance = _requireObject(json, 'finance');
  final document = _requireObject(json, 'document');

  String formField(String key) => _requireString(form, key, 'form.$key');

  return ContractDetail(
    contract: contractFrom(json),
    form: ContractForm(
      lastName: formField('last_name'),
      firstName: formField('first_name'),
      register: formField('register'),
      phone: formField('phone'),
      email: formField('email'),
      address: formField('address'),
      guardianRelation: formField('guardian_relation'),
      guardianLastName: formField('guardian_last_name'),
      guardianFirstName: formField('guardian_first_name'),
      guardianRegister: formField('guardian_register'),
      finalPaymentDate: formField('final_payment_date'),
    ),
    rules: ContractRules(
      guardianRequired: _requireBool(rules, 'guardian_required'),
      finalPaymentDateRequired: _requireBool(
        rules,
        'final_payment_date_required',
      ),
      finalPaymentDateMin: _requireDate(rules, 'final_payment_date_min'),
      finalPaymentDateMax: rules['final_payment_date_max'] == null
          ? null
          : _requireDate(rules, 'final_payment_date_max'),
    ),
    finance: ContractFinance(
      totalDue: _requireNum(finance, 'total_due').toDouble(),
      totalPaid: _requireNum(finance, 'total_paid').toDouble(),
      balance: _requireNum(finance, 'balance').toDouble(),
      discountPercent: _requireWholeNumber(finance, 'discount_percent'),
      currency: _requireString(finance, 'currency', 'finance.currency'),
    ),
    document: ContractDocument(
      format: _requireString(document, 'format', 'document.format'),
      preview: _optionalString(document, 'preview', 'document.preview'),
      download: _optionalString(document, 'download', 'document.download'),
    ),
  );
}

Map<String, dynamic> _object(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException catch (e) {
    throw ContractFailure(
      ContractFailureKind.server,
      detail: 'malformed JSON: ${e.message}',
    );
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ContractFailure(
      ContractFailureKind.server,
      detail: 'response was not a JSON object',
    );
  }
  return decoded;
}

Never _malformed(String field, String expected) => throw ContractFailure(
  ContractFailureKind.server,
  detail: '$field: expected $expected',
);

Map<String, dynamic> _requireObject(Map<String, dynamic> json, String key) =>
    json[key] is Map<String, dynamic>
    ? json[key] as Map<String, dynamic>
    : _malformed(key, 'an object');

/// A string, empty allowed — the form sends `""` for an empty field.
String _requireString(Map<String, dynamic> json, String key, String field) =>
    json[key] is String ? json[key] as String : _malformed(field, 'a string');

String? _optionalString(Map<String, dynamic> json, String key, String field) {
  final value = json[key];
  if (value == null) return null;
  return value is String ? value : _malformed(field, 'a string or null');
}

bool _requireBool(Map<String, dynamic> json, String key) =>
    json[key] is bool ? json[key] as bool : _malformed('rules.$key', 'a bool');

num _requireNum(Map<String, dynamic> json, String key) => json[key] is num
    ? json[key] as num
    : _malformed('finance.$key', 'a number');

int _requireWholeNumber(Map<String, dynamic> json, String key) {
  final value = _requireNum(json, key);
  return value == value.roundToDouble()
      ? value.toInt()
      : _malformed('finance.$key', 'a whole number');
}

/// A bare `YYYY-MM-DD` date.
DateTime _requireDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  final date = value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
      ? DateTime.tryParse(value)
      : null;
  return date ?? _malformed('rules.$key', 'a YYYY-MM-DD date');
}

/// One contract item, read leniently. Public so the mapping can be tested on
/// its own.
StudentContract contractFrom(Map<String, dynamic> json) {
  final course = json['course'];
  final cohort = json['cohort'];
  final title = course is Map<String, dynamic> ? course['title'] : null;
  return StudentContract(
    id: _id(json['id']),
    contractNumber: _string(json['contract_number']),
    status: StudentContractStatus.fromApi(json['status']),
    course: course is Map<String, dynamic>
        ? ContractCourse(
            id: _int(course['id']),
            slug: _string(course['slug']),
            titleMn: title is Map<String, dynamic>
                ? _string(title['mn'])
                : null,
            titleEn: title is Map<String, dynamic>
                ? _string(title['en'])
                : null,
            level: _string(course['level']),
          )
        : null,
    cohort: cohort is Map<String, dynamic>
        ? ContractCohort(
            id: _int(cohort['id']),
            name: _string(cohort['name']),
            startDate: _time(cohort['start_date']),
            endDate: _time(cohort['end_date']),
          )
        : null,
    createdAt: _time(json['created_at']),
    signedAt: _time(json['signed_at']),
    cancelledAt: _time(json['cancelled_at']),
    canView: json['can_view'] == true,
    canSign: json['can_sign'] == true,
    isCurrent: json['is_current'] == true,
    documentUrl: _string(json['document_url']),
  );
}

String? _string(Object? raw) => raw is String && raw.isNotEmpty ? raw : null;

int? _int(Object? raw) => raw is int ? raw : null;

DateTime? _time(Object? raw) => raw is String ? DateTime.tryParse(raw) : null;

String? _id(Object? raw) => switch (raw) {
  final int id => '$id',
  final String id when id.isNotEmpty => id,
  _ => null,
};
