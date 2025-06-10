;; Collaboration Framework Contract
;; Facilitates technology collaboration between institutions

(define-constant contract-owner tx-sender)
(define-constant err-not-found (err u400))
(define-constant err-unauthorized (err u401))
(define-constant err-invalid-status (err u402))
(define-constant err-already-member (err u403))

;; Collaboration status
(define-constant status-proposed u1)
(define-constant status-active u2)
(define-constant status-completed u3)
(define-constant status-cancelled u4)

;; Data structures
(define-map collaborations
  { collaboration-id: uint }
  {
    initiator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    objectives: (string-ascii 300),
    start-date: uint,
    end-date: uint,
    status: uint,
    max-participants: uint,
    current-participants: uint
  }
)

(define-map collaboration-members
  { collaboration-id: uint, member: principal }
  {
    join-date: uint,
    role: (string-ascii 50),
    contribution: (string-ascii 200),
    is-active: bool
  }
)

(define-map collaboration-counter
  { key: (string-ascii 10) }
  { value: uint }
)

;; Initialize counter
(map-set collaboration-counter { key: "counter" } { value: u0 })

;; Public functions
(define-public (create-collaboration
  (title (string-ascii 100))
  (description (string-ascii 500))
  (objectives (string-ascii 300))
  (duration uint)
  (max-participants uint)
)
  (let ((collaboration-id (+ (get value (default-to { value: u0 } (map-get? collaboration-counter { key: "counter" }))) u1)))
    (map-set collaborations
      { collaboration-id: collaboration-id }
      {
        initiator: tx-sender,
        title: title,
        description: description,
        objectives: objectives,
        start-date: block-height,
        end-date: (+ block-height duration),
        status: status-proposed,
        max-participants: max-participants,
        current-participants: u1
      }
    )

    ;; Add initiator as first member
    (map-set collaboration-members
      { collaboration-id: collaboration-id, member: tx-sender }
      {
        join-date: block-height,
        role: "initiator",
        contribution: "Project leadership",
        is-active: true
      }
    )

    (map-set collaboration-counter { key: "counter" } { value: collaboration-id })
    (ok collaboration-id)
  )
)

(define-public (join-collaboration
  (collaboration-id uint)
  (role (string-ascii 50))
  (contribution (string-ascii 200))
)
  (let ((collaboration (unwrap! (map-get? collaborations { collaboration-id: collaboration-id }) err-not-found)))
    (asserts! (is-none (map-get? collaboration-members { collaboration-id: collaboration-id, member: tx-sender })) err-already-member)
    (asserts! (< (get current-participants collaboration) (get max-participants collaboration)) err-invalid-status)

    (map-set collaboration-members
      { collaboration-id: collaboration-id, member: tx-sender }
      {
        join-date: block-height,
        role: role,
        contribution: contribution,
        is-active: true
      }
    )

    (map-set collaborations
      { collaboration-id: collaboration-id }
      (merge collaboration {
        current-participants: (+ (get current-participants collaboration) u1)
      })
    )
    (ok true)
  )
)

(define-public (activate-collaboration (collaboration-id uint))
  (let ((collaboration (unwrap! (map-get? collaborations { collaboration-id: collaboration-id }) err-not-found)))
    (asserts! (is-eq tx-sender (get initiator collaboration)) err-unauthorized)
    (asserts! (is-eq (get status collaboration) status-proposed) err-invalid-status)

    (map-set collaborations
      { collaboration-id: collaboration-id }
      (merge collaboration { status: status-active })
    )
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-collaboration (collaboration-id uint))
  (map-get? collaborations { collaboration-id: collaboration-id })
)

(define-read-only (get-member-info (collaboration-id uint) (member principal))
  (map-get? collaboration-members { collaboration-id: collaboration-id, member: member })
)

(define-read-only (is-collaboration-member (collaboration-id uint) (member principal))
  (is-some (map-get? collaboration-members { collaboration-id: collaboration-id, member: member }))
)
