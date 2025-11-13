;; credential-issuance-and-storage
;; Manages issuance, storage, and sharing of academic credentials

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_INSTITUTION_INACTIVE (err u104))
(define-constant ERR_CREDENTIAL_REVOKED (err u105))

;; Data Variables
(define-data-var next-credential-id uint u1)
(define-data-var next-institution-id uint u1)
(define-data-var total-credentials-issued uint u0)
(define-data-var total-institutions uint u0)

;; Data Maps

;; Store accredited institutions
(define-map institutions
  { institution-id: uint }
  {
    admin: principal,
    name: (string-ascii 100),
    country: (string-ascii 50),
    accreditation-status: bool,
    credentials-issued: uint,
    registration-date: uint,
    active: bool
  }
)

;; Map institution admins to their institution ID
(define-map institution-admins
  { admin: principal }
  { institution-id: uint }
)

;; Store academic credentials
(define-map credentials
  { credential-id: uint }
  {
    student: principal,
    institution-id: uint,
    credential-type: (string-ascii 30),
    title: (string-ascii 100),
    field-of-study: (string-ascii 100),
    degree-level: (string-ascii 50),
    grade: (string-ascii 20),
    issue-date: uint,
    completion-date: uint,
    credential-hash: (buff 32),
    metadata-uri: (string-ascii 256),
    revoked: bool
  }
)

;; Map students to their credentials
(define-map student-credentials
  { student: principal, index: uint }
  { credential-id: uint }
)

;; Track number of credentials per student
(define-map student-credential-count
  { student: principal }
  { count: uint }
)

;; Granular credential sharing permissions
(define-map credential-shares
  { credential-id: uint, viewer: principal }
  {
    granted-by: principal,
    granted-at: uint,
    expires-at: (optional uint),
    view-only: bool
  }
)

;; Learning records for comprehensive educational history
(define-map learning-records
  { student: principal, record-id: uint }
  {
    credential-id: uint,
    course-code: (string-ascii 20),
    course-name: (string-ascii 100),
    credits: uint,
    grade: (string-ascii 10),
    semester: (string-ascii 20),
    year: uint,
    skills-gained: (string-ascii 256)
  }
)

;; Track learning record count
(define-map learning-record-count
  { student: principal }
  { count: uint }
)

;; Transfer credit verification between institutions
(define-map transfer-credits
  { student: principal, from-institution: uint, to-institution: uint }
  {
    credits-transferred: uint,
    verification-date: uint,
    verified-by: principal,
    status: (string-ascii 20)
  }
)

;; Public Functions

;; Register a new institution
(define-public (register-institution
    (admin principal)
    (name (string-ascii 100))
    (country (string-ascii 50))
    (accreditation-status bool)
  )
  (let
    (
      (institution-id (var-get next-institution-id))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? institution-admins { admin: admin })) ERR_ALREADY_EXISTS)
    (map-set institutions
      { institution-id: institution-id }
      {
        admin: admin,
        name: name,
        country: country,
        accreditation-status: accreditation-status,
        credentials-issued: u0,
        registration-date: stacks-block-height,
        active: true
      }
    )
    (map-set institution-admins
      { admin: admin }
      { institution-id: institution-id }
    )
    (var-set next-institution-id (+ institution-id u1))
    (var-set total-institutions (+ (var-get total-institutions) u1))
    (ok institution-id)
  )
)

;; Issue a new credential
(define-public (issue-credential
    (student principal)
    (credential-type (string-ascii 30))
    (title (string-ascii 100))
    (field-of-study (string-ascii 100))
    (degree-level (string-ascii 50))
    (grade (string-ascii 20))
    (completion-date uint)
    (credential-hash (buff 32))
    (metadata-uri (string-ascii 256))
  )
  (let
    (
      (credential-id (var-get next-credential-id))
      (institution-data (unwrap! (map-get? institution-admins { admin: tx-sender }) ERR_UNAUTHORIZED))
      (institution-id (get institution-id institution-data))
      (institution (unwrap! (map-get? institutions { institution-id: institution-id }) ERR_NOT_FOUND))
      (student-count (default-to u0 (get count (map-get? student-credential-count { student: student }))))
    )
    (asserts! (get active institution) ERR_INSTITUTION_INACTIVE)
    (map-set credentials
      { credential-id: credential-id }
      {
        student: student,
        institution-id: institution-id,
        credential-type: credential-type,
        title: title,
        field-of-study: field-of-study,
        degree-level: degree-level,
        grade: grade,
        issue-date: stacks-block-height,
        completion-date: completion-date,
        credential-hash: credential-hash,
        metadata-uri: metadata-uri,
        revoked: false
      }
    )
    (map-set student-credentials
      { student: student, index: student-count }
      { credential-id: credential-id }
    )
    (map-set student-credential-count
      { student: student }
      { count: (+ student-count u1) }
    )
    (map-set institutions
      { institution-id: institution-id }
      (merge institution { credentials-issued: (+ (get credentials-issued institution) u1) })
    )
    (var-set next-credential-id (+ credential-id u1))
    (var-set total-credentials-issued (+ (var-get total-credentials-issued) u1))
    (ok credential-id)
  )
)

;; Share credential with specific viewer
(define-public (share-credential
    (credential-id uint)
    (viewer principal)
    (expires-at (optional uint))
  )
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get student credential)) ERR_UNAUTHORIZED)
    (asserts! (not (get revoked credential)) ERR_CREDENTIAL_REVOKED)
    (map-set credential-shares
      { credential-id: credential-id, viewer: viewer }
      {
        granted-by: tx-sender,
        granted-at: stacks-block-height,
        expires-at: expires-at,
        view-only: true
      }
    )
    (ok true)
  )
)

;; Revoke credential share
(define-public (revoke-credential-share
    (credential-id uint)
    (viewer principal)
  )
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get student credential)) ERR_UNAUTHORIZED)
    (map-delete credential-shares { credential-id: credential-id, viewer: viewer })
    (ok true)
  )
)

;; Add learning record
(define-public (add-learning-record
    (student principal)
    (credential-id uint)
    (course-code (string-ascii 20))
    (course-name (string-ascii 100))
    (credits uint)
    (grade (string-ascii 10))
    (semester (string-ascii 20))
    (year uint)
    (skills-gained (string-ascii 256))
  )
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR_NOT_FOUND))
      (institution-data (unwrap! (map-get? institution-admins { admin: tx-sender }) ERR_UNAUTHORIZED))
      (record-count (default-to u0 (get count (map-get? learning-record-count { student: student }))))
    )
    (asserts! (is-eq student (get student credential)) ERR_INVALID_INPUT)
    (map-set learning-records
      { student: student, record-id: record-count }
      {
        credential-id: credential-id,
        course-code: course-code,
        course-name: course-name,
        credits: credits,
        grade: grade,
        semester: semester,
        year: year,
        skills-gained: skills-gained
      }
    )
    (map-set learning-record-count
      { student: student }
      { count: (+ record-count u1) }
    )
    (ok record-count)
  )
)

;; Verify transfer credits
(define-public (verify-transfer-credits
    (student principal)
    (from-institution uint)
    (credits-transferred uint)
    (status (string-ascii 20))
  )
  (let
    (
      (institution-data (unwrap! (map-get? institution-admins { admin: tx-sender }) ERR_UNAUTHORIZED))
      (to-institution (get institution-id institution-data))
    )
    (map-set transfer-credits
      { student: student, from-institution: from-institution, to-institution: to-institution }
      {
        credits-transferred: credits-transferred,
        verification-date: stacks-block-height,
        verified-by: tx-sender,
        status: status
      }
    )
    (ok true)
  )
)

;; Revoke a credential (institution only)
(define-public (revoke-credential (credential-id uint))
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR_NOT_FOUND))
      (institution-data (unwrap! (map-get? institution-admins { admin: tx-sender }) ERR_UNAUTHORIZED))
    )
    (asserts! (is-eq (get institution-id institution-data) (get institution-id credential)) ERR_UNAUTHORIZED)
    (map-set credentials
      { credential-id: credential-id }
      (merge credential { revoked: true })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get credential details
(define-read-only (get-credential (credential-id uint))
  (ok (map-get? credentials { credential-id: credential-id }))
)

;; Get institution details
(define-read-only (get-institution (institution-id uint))
  (ok (map-get? institutions { institution-id: institution-id }))
)

;; Get student credential by index
(define-read-only (get-student-credential (student principal) (index uint))
  (ok (map-get? student-credentials { student: student, index: index }))
)

;; Get student credential count
(define-read-only (get-student-credential-count (student principal))
  (ok (default-to u0 (get count (map-get? student-credential-count { student: student }))))
)

;; Check if viewer can access credential
(define-read-only (can-view-credential (credential-id uint) (viewer principal))
  (let
    (
      (credential (unwrap! (map-get? credentials { credential-id: credential-id }) ERR_NOT_FOUND))
      (share (map-get? credential-shares { credential-id: credential-id, viewer: viewer }))
    )
    (ok
      (or
        (is-eq viewer (get student credential))
        (and
          (is-some share)
          (match (get expires-at (unwrap-panic share))
            expiry (< stacks-block-height expiry)
            true
          )
        )
      )
    )
  )
)

;; Get learning record
(define-read-only (get-learning-record (student principal) (record-id uint))
  (ok (map-get? learning-records { student: student, record-id: record-id }))
)

;; Get transfer credit info
(define-read-only (get-transfer-credits (student principal) (from-institution uint) (to-institution uint))
  (ok (map-get? transfer-credits { student: student, from-institution: from-institution, to-institution: to-institution }))
)

;; Get contract stats
(define-read-only (get-contract-stats)
  (ok {
    total-credentials: (var-get total-credentials-issued),
    total-institutions: (var-get total-institutions),
    next-credential-id: (var-get next-credential-id),
    next-institution-id: (var-get next-institution-id)
  })
)
