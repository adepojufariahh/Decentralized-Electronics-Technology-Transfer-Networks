;; Commercialization Support Contract
;; Supports electronics technology commercialization processes

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u500))
(define-constant err-unauthorized (err u501))
(define-constant err-insufficient-funds (err u502))
(define-constant err-invalid-status (err u503))

;; Commercialization phases
(define-constant phase-planning u1)
(define-constant phase-funding u2)
(define-constant phase-development u3)
(define-constant phase-market-entry u4)
(define-constant phase-scaling u5)

;; Data structures
(define-map commercialization-projects
  { project-id: uint }
  {
    owner: principal,
    innovation-id: uint,
    project-name: (string-ascii 100),
    market-analysis: (string-ascii 500),
    funding-goal: uint,
    current-funding: uint,
    current-phase: uint,
    start-date: uint,
    target-launch: uint,
    is-active: bool
  }
)

(define-map project-milestones
  { project-id: uint, milestone-id: uint }
  {
    description: (string-ascii 200),
    target-date: uint,
    completion-date: (optional uint),
    is-completed: bool
  }
)

(define-map funding-contributions
  { project-id: uint, contributor: principal }
  {
    amount: uint,
    contribution-date: uint,
    equity-percentage: uint
  }
)

(define-map project-counter
  { key: (string-ascii 10) }
  { value: uint }
)

;; Initialize counter
(map-set project-counter { key: "counter" } { value: u0 })

;; Public functions
(define-public (create-commercialization-project
  (innovation-id uint)
  (project-name (string-ascii 100))
  (market-analysis (string-ascii 500))
  (funding-goal uint)
  (target-launch uint)
)
  (let ((project-id (+ (get value (default-to { value: u0 } (map-get? project-counter { key: "counter" }))) u1)))
    (map-set commercialization-projects
      { project-id: project-id }
      {
        owner: tx-sender,
        innovation-id: innovation-id,
        project-name: project-name,
        market-analysis: market-analysis,
        funding-goal: funding-goal,
        current-funding: u0,
        current-phase: phase-planning,
        start-date: block-height,
        target-launch: target-launch,
        is-active: true
      }
    )
    (map-set project-counter { key: "counter" } { value: project-id })
    (ok project-id)
  )
)

(define-public (contribute-funding (project-id uint) (equity-percentage uint))
  (let ((project (unwrap! (map-get? commercialization-projects { project-id: project-id }) err-not-found))
        (contribution-amount (stx-get-balance tx-sender)))
    (asserts! (> contribution-amount u0) err-insufficient-funds)
    (asserts! (get is-active project) err-invalid-status)

    ;; Record contribution
    (map-set funding-contributions
      { project-id: project-id, contributor: tx-sender }
      {
        amount: contribution-amount,
        contribution-date: block-height,
        equity-percentage: equity-percentage
      }
    )

    ;; Update project funding
    (map-set commercialization-projects
      { project-id: project-id }
      (merge project {
        current-funding: (+ (get current-funding project) contribution-amount)
      })
    )
    (ok true)
  )
)

(define-public (update-project-phase (project-id uint) (new-phase uint))
  (let ((project (unwrap! (map-get? commercialization-projects { project-id: project-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get owner project)) err-unauthorized)
    (asserts! (and (>= new-phase phase-planning) (<= new-phase phase-scaling)) err-invalid-status)

    (map-set commercialization-projects
      { project-id: project-id }
      (merge project { current-phase: new-phase })
    )
    (ok true)
  )
)

(define-public (add-milestone
  (project-id uint)
  (milestone-id uint)
  (description (string-ascii 200))
  (target-date uint)
)
  (let ((project (unwrap! (map-get? commercialization-projects { project-id: project-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get owner project)) err-unauthorized)

    (map-set project-milestones
      { project-id: project-id, milestone-id: milestone-id }
      {
        description: description,
        target-date: target-date,
        completion-date: none,
        is-completed: false
      }
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-project (project-id uint))
  (map-get? commercialization-projects { project-id: project-id })
)

(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? project-milestones { project-id: project-id, milestone-id: milestone-id })
)

(define-read-only (get-funding-info (project-id uint) (contributor principal))
  (map-get? funding-contributions { project-id: project-id, contributor: contributor })
)

(define-read-only (get-funding-progress (project-id uint))
  (match (map-get? commercialization-projects { project-id: project-id })
    project (/ (* (get current-funding project) u100) (get funding-goal project))
    u0
  )
)
