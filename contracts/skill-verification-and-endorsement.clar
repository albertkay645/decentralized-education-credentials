;; skill-verification-and-endorsement
;; Manages skill endorsements, reputation tracking, and competency verification

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_NOT_FOUND (err u201))
(define-constant ERR_SELF_ENDORSEMENT (err u202))
(define-constant ERR_ALREADY_ENDORSED (err u203))
(define-constant ERR_INVALID_RATING (err u204))
(define-constant ERR_SKILL_NOT_VERIFIED (err u205))
(define-constant ERR_INVALID_INPUT (err u206))

;; Skill categories
(define-constant CATEGORY_TECHNICAL u1)
(define-constant CATEGORY_BUSINESS u2)
(define-constant CATEGORY_CREATIVE u3)
(define-constant CATEGORY_LEADERSHIP u4)
(define-constant CATEGORY_COMMUNICATION u5)

;; Data Variables
(define-data-var next-skill-id uint u1)
(define-data-var next-endorsement-id uint u1)
(define-data-var next-job-id uint u1)
(define-data-var next-offering-id uint u1)
(define-data-var total-skills uint u0)
(define-data-var total-endorsements uint u0)

;; Data Maps

;; Store registered skills
(define-map skills
  { skill-id: uint }
  {
    owner: principal,
    skill-name: (string-ascii 100),
    category: uint,
    proficiency-level: uint,
    years-experience: uint,
    description: (string-ascii 256),
    certification-uri: (optional (string-ascii 256)),
    created-at: uint,
    verified: bool
  }
)

;; Map users to their skills
(define-map user-skills
  { user: principal, index: uint }
  { skill-id: uint }
)

;; Track skill count per user
(define-map user-skill-count
  { user: principal }
  { count: uint }
)

;; Store skill endorsements
(define-map endorsements
  { endorsement-id: uint }
  {
    skill-id: uint,
    endorser: principal,
    endorsee: principal,
    proficiency-rating: uint,
    relationship: (string-ascii 50),
    comment: (string-ascii 256),
    endorsed-at: uint,
    weight: uint
  }
)

;; Track endorsements to prevent duplicates
(define-map endorsement-tracker
  { skill-id: uint, endorser: principal }
  { endorsed: bool }
)

;; Skill endorsement statistics
(define-map skill-stats
  { skill-id: uint }
  {
    total-endorsements: uint,
    average-rating: uint,
    rating-sum: uint
  }
)

;; User reputation scores
(define-map user-reputation
  { user: principal }
  {
    reputation-score: uint,
    endorsements-received: uint,
    endorsements-given: uint,
    verified-skills: uint,
    last-updated: uint
  }
)

;; Job requirements for skill matching
(define-map job-requirements
  { job-id: uint }
  {
    employer: principal,
    title: (string-ascii 100),
    required-skills: (list 10 uint),
    minimum-proficiency: uint,
    minimum-endorsements: uint,
    posted-at: uint,
    active: bool
  }
)

;; Candidate job matches
(define-map candidate-matches
  { job-id: uint, candidate: principal }
  {
    matched-skills: uint,
    total-required: uint,
    match-percentage: uint,
    qualified: bool,
    evaluated-at: uint
  }
)

;; Continuing education records
(define-map continuing-education
  { user: principal, education-id: uint }
  {
    skill-id: uint,
    course-name: (string-ascii 100),
    provider: (string-ascii 100),
    completion-date: uint,
    hours: uint,
    certificate-uri: (string-ascii 256)
  }
)

;; Track education record count
(define-map education-count
  { user: principal }
  { count: uint }
)

;; Skill marketplace offerings
(define-map skill-offerings
  { offering-id: uint }
  {
    instructor: principal,
    skill-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 256),
    price-per-hour: uint,
    available: bool,
    rating: uint,
    total-students: uint
  }
)

;; Track offerings per instructor
(define-map instructor-offerings
  { instructor: principal, index: uint }
  { offering-id: uint }
)

(define-map offering-count
  { instructor: principal }
  { count: uint }
)

;; Public Functions

;; Register a new skill
(define-public (register-skill
    (skill-name (string-ascii 100))
    (category uint)
    (proficiency-level uint)
    (years-experience uint)
    (description (string-ascii 256))
    (certification-uri (optional (string-ascii 256)))
  )
  (let
    (
      (skill-id (var-get next-skill-id))
      (user-count (default-to u0 (get count (map-get? user-skill-count { user: tx-sender }))))
    )
    (asserts! (and (<= category u5) (>= category u1)) ERR_INVALID_INPUT)
    (asserts! (and (<= proficiency-level u10) (>= proficiency-level u1)) ERR_INVALID_INPUT)
    (map-set skills
      { skill-id: skill-id }
      {
        owner: tx-sender,
        skill-name: skill-name,
        category: category,
        proficiency-level: proficiency-level,
        years-experience: years-experience,
        description: description,
        certification-uri: certification-uri,
        created-at: stacks-block-height,
        verified: false
      }
    )
    (map-set user-skills
      { user: tx-sender, index: user-count }
      { skill-id: skill-id }
    )
    (map-set user-skill-count
      { user: tx-sender }
      { count: (+ user-count u1) }
    )
    (var-set next-skill-id (+ skill-id u1))
    (var-set total-skills (+ (var-get total-skills) u1))
    (ok skill-id)
  )
)

;; Endorse a skill
(define-public (endorse-skill
    (skill-id uint)
    (proficiency-rating uint)
    (relationship (string-ascii 50))
    (comment (string-ascii 256))
    (weight uint)
  )
  (let
    (
      (skill (unwrap! (map-get? skills { skill-id: skill-id }) ERR_NOT_FOUND))
      (endorsement-id (var-get next-endorsement-id))
      (stats (default-to { total-endorsements: u0, average-rating: u0, rating-sum: u0 }
               (map-get? skill-stats { skill-id: skill-id })))
      (endorsee (get owner skill))
    )
    (asserts! (not (is-eq tx-sender endorsee)) ERR_SELF_ENDORSEMENT)
    (asserts! (and (<= proficiency-rating u100) (>= proficiency-rating u1)) ERR_INVALID_RATING)
    (asserts! (and (<= weight u10) (>= weight u1)) ERR_INVALID_INPUT)
    (asserts! (is-none (map-get? endorsement-tracker { skill-id: skill-id, endorser: tx-sender }))
              ERR_ALREADY_ENDORSED)
    
    (map-set endorsements
      { endorsement-id: endorsement-id }
      {
        skill-id: skill-id,
        endorser: tx-sender,
        endorsee: endorsee,
        proficiency-rating: proficiency-rating,
        relationship: relationship,
        comment: comment,
        endorsed-at: stacks-block-height,
        weight: weight
      }
    )
    
    (map-set endorsement-tracker
      { skill-id: skill-id, endorser: tx-sender }
      { endorsed: true }
    )
    
    (let
      (
        (new-total (+ (get total-endorsements stats) u1))
        (new-sum (+ (get rating-sum stats) proficiency-rating))
        (new-avg (/ new-sum new-total))
      )
      (map-set skill-stats
        { skill-id: skill-id }
        {
          total-endorsements: new-total,
          average-rating: new-avg,
          rating-sum: new-sum
        }
      )
      
      ;; Verify skill if it has 3+ endorsements
      (if (>= new-total u3)
        (map-set skills
          { skill-id: skill-id }
          (merge skill { verified: true })
        )
        true
      )
    )
    
    (update-reputation endorsee true)
    (update-reputation tx-sender false)
    
    (var-set next-endorsement-id (+ endorsement-id u1))
    (var-set total-endorsements (+ (var-get total-endorsements) u1))
    (ok endorsement-id)
  )
)

;; Create job requirement
(define-public (create-job-requirement
    (title (string-ascii 100))
    (required-skills (list 10 uint))
    (minimum-proficiency uint)
    (minimum-endorsements uint)
  )
  (let
    (
      (job-id (var-get next-job-id))
    )
    (map-set job-requirements
      { job-id: job-id }
      {
        employer: tx-sender,
        title: title,
        required-skills: required-skills,
        minimum-proficiency: minimum-proficiency,
        minimum-endorsements: minimum-endorsements,
        posted-at: stacks-block-height,
        active: true
      }
    )
    (var-set next-job-id (+ job-id u1))
    (ok job-id)
  )
)

;; Evaluate candidate for job
(define-public (evaluate-candidate (job-id uint) (candidate principal))
  (let
    (
      (job (unwrap! (map-get? job-requirements { job-id: job-id }) ERR_NOT_FOUND))
      (required-skills (get required-skills job))
      (total-required (len required-skills))
    )
    (asserts! (is-eq tx-sender (get employer job)) ERR_UNAUTHORIZED)
    
    (let
      (
        (matched-count u0)
        (match-percentage u0)
        (qualified false)
      )
      (map-set candidate-matches
        { job-id: job-id, candidate: candidate }
        {
          matched-skills: matched-count,
          total-required: total-required,
          match-percentage: match-percentage,
          qualified: qualified,
          evaluated-at: stacks-block-height
        }
      )
      (ok true)
    )
  )
)

;; Add continuing education record
(define-public (add-continuing-education
    (skill-id uint)
    (course-name (string-ascii 100))
    (provider (string-ascii 100))
    (completion-date uint)
    (hours uint)
    (certificate-uri (string-ascii 256))
  )
  (let
    (
      (skill (unwrap! (map-get? skills { skill-id: skill-id }) ERR_NOT_FOUND))
      (education-id (default-to u0 (get count (map-get? education-count { user: tx-sender }))))
    )
    (asserts! (is-eq tx-sender (get owner skill)) ERR_UNAUTHORIZED)
    
    (map-set continuing-education
      { user: tx-sender, education-id: education-id }
      {
        skill-id: skill-id,
        course-name: course-name,
        provider: provider,
        completion-date: completion-date,
        hours: hours,
        certificate-uri: certificate-uri
      }
    )
    
    (map-set education-count
      { user: tx-sender }
      { count: (+ education-id u1) }
    )
    (ok education-id)
  )
)

;; Create skill offering for marketplace
(define-public (create-skill-offering
    (skill-id uint)
    (title (string-ascii 100))
    (description (string-ascii 256))
    (price-per-hour uint)
  )
  (let
    (
      (skill (unwrap! (map-get? skills { skill-id: skill-id }) ERR_NOT_FOUND))
      (offering-id (var-get next-offering-id))
      (instructor-count (default-to u0 (get count (map-get? offering-count { instructor: tx-sender }))))
    )
    (asserts! (is-eq tx-sender (get owner skill)) ERR_UNAUTHORIZED)
    (asserts! (get verified skill) ERR_SKILL_NOT_VERIFIED)
    (asserts! (> price-per-hour u0) ERR_INVALID_INPUT)
    
    (map-set skill-offerings
      { offering-id: offering-id }
      {
        instructor: tx-sender,
        skill-id: skill-id,
        title: title,
        description: description,
        price-per-hour: price-per-hour,
        available: true,
        rating: u0,
        total-students: u0
      }
    )
    
    (map-set instructor-offerings
      { instructor: tx-sender, index: instructor-count }
      { offering-id: offering-id }
    )
    
    (map-set offering-count
      { instructor: tx-sender }
      { count: (+ instructor-count u1) }
    )
    
    (var-set next-offering-id (+ offering-id u1))
    (ok offering-id)
  )
)

;; Private Functions

;; Update user reputation
(define-private (update-reputation (user principal) (is-received bool))
  (let
    (
      (reputation (default-to
        { reputation-score: u0, endorsements-received: u0, endorsements-given: u0, verified-skills: u0, last-updated: u0 }
        (map-get? user-reputation { user: user })
      ))
    )
    (if is-received
      (let
        (
          (new-received (+ (get endorsements-received reputation) u1))
          (new-score (+ (get reputation-score reputation) u10))
        )
        (map-set user-reputation
          { user: user }
          (merge reputation {
            endorsements-received: new-received,
            reputation-score: new-score,
            last-updated: stacks-block-height
          })
        )
      )
      (map-set user-reputation
        { user: user }
        (merge reputation {
          endorsements-given: (+ (get endorsements-given reputation) u1),
          last-updated: stacks-block-height
        })
      )
    )
  )
)

;; Read-only Functions

;; Get skill details
(define-read-only (get-skill (skill-id uint))
  (ok (map-get? skills { skill-id: skill-id }))
)

;; Get user skill by index
(define-read-only (get-user-skill (user principal) (index uint))
  (ok (map-get? user-skills { user: user, index: index }))
)

;; Get user skill count
(define-read-only (get-user-skill-count (user principal))
  (ok (default-to u0 (get count (map-get? user-skill-count { user: user }))))
)

;; Get endorsement details
(define-read-only (get-endorsement (endorsement-id uint))
  (ok (map-get? endorsements { endorsement-id: endorsement-id }))
)

;; Get skill statistics
(define-read-only (get-skill-stats (skill-id uint))
  (ok (map-get? skill-stats { skill-id: skill-id }))
)

;; Get user reputation
(define-read-only (get-user-reputation (user principal))
  (ok (map-get? user-reputation { user: user }))
)

;; Get job requirement
(define-read-only (get-job-requirement (job-id uint))
  (ok (map-get? job-requirements { job-id: job-id }))
)

;; Get candidate match
(define-read-only (get-candidate-match (job-id uint) (candidate principal))
  (ok (map-get? candidate-matches { job-id: job-id, candidate: candidate }))
)

;; Get education record
(define-read-only (get-education-record (user principal) (education-id uint))
  (ok (map-get? continuing-education { user: user, education-id: education-id }))
)

;; Get skill offering
(define-read-only (get-skill-offering (offering-id uint))
  (ok (map-get? skill-offerings { offering-id: offering-id }))
)

;; Get contract statistics
(define-read-only (get-contract-stats)
  (ok {
    total-skills: (var-get total-skills),
    total-endorsements: (var-get total-endorsements),
    next-skill-id: (var-get next-skill-id),
    next-endorsement-id: (var-get next-endorsement-id),
    next-job-id: (var-get next-job-id)
  })
)
