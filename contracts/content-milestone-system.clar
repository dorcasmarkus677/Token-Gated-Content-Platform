(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_CLAIMED (err u105))
(define-constant ERR_THRESHOLD_NOT_MET (err u106))
(define-constant ERR_INVALID_PARAMS (err u107))

(define-map content-milestones
  { content-id: uint, milestone-id: uint }
  {
    creator: principal,
    milestone-type: (string-ascii 20),
    threshold: uint,
    badge-name: (string-ascii 50),
    reward-enabled: bool,
    total-achievers: uint
  }
)

(define-map user-achievements
  { user: principal, content-id: uint, milestone-id: uint }
  {
    achieved-at: uint,
    metric-value: uint,
    badge-claimed: bool
  }
)

(define-map user-achievement-count
  { user: principal }
  { total-badges: uint, total-value: uint }
)

(define-map milestone-leaderboard
  { content-id: uint, milestone-id: uint }
  { 
    first-achiever: (optional principal),
    first-achieved-at: (optional uint),
    latest-achiever: (optional principal)
  }
)

(define-data-var next-milestone-id uint u1)

(define-public (create-milestone
  (content-id uint)
  (milestone-type (string-ascii 20))
  (threshold uint)
  (badge-name (string-ascii 50))
)
  (let
    (
      (milestone-id (var-get next-milestone-id))
      (content-data (unwrap! (contract-call? .Token-Gated-Content-Platform get-content-info content-id) ERR_NOT_FOUND))
      (creator (get creator content-data))
    )
    (asserts! (is-eq tx-sender creator) ERR_UNAUTHORIZED)
    (asserts! (> threshold u0) ERR_INVALID_PARAMS)
    (map-set content-milestones
      { content-id: content-id, milestone-id: milestone-id }
      {
        creator: creator,
        milestone-type: milestone-type,
        threshold: threshold,
        badge-name: badge-name,
        reward-enabled: true,
        total-achievers: u0
      }
    )
    (var-set next-milestone-id (+ milestone-id u1))
    (ok milestone-id)
  )
)

(define-public (claim-achievement
  (content-id uint)
  (milestone-id uint)
  (current-metric uint)
)
  (let
    (
      (milestone-data (unwrap! (map-get? content-milestones { content-id: content-id, milestone-id: milestone-id }) ERR_NOT_FOUND))
      (existing-achievement (map-get? user-achievements { user: tx-sender, content-id: content-id, milestone-id: milestone-id }))
      (user-stats (default-to { total-badges: u0, total-value: u0 } (map-get? user-achievement-count { user: tx-sender })))
      (leaderboard (default-to { first-achiever: none, first-achieved-at: none, latest-achiever: none }
        (map-get? milestone-leaderboard { content-id: content-id, milestone-id: milestone-id })))
    )
    (asserts! (is-none existing-achievement) ERR_ALREADY_CLAIMED)
    (asserts! (get reward-enabled milestone-data) ERR_UNAUTHORIZED)
    (asserts! (>= current-metric (get threshold milestone-data)) ERR_THRESHOLD_NOT_MET)
    (map-set user-achievements
      { user: tx-sender, content-id: content-id, milestone-id: milestone-id }
      { achieved-at: stacks-block-height, metric-value: current-metric, badge-claimed: true }
    )
    (map-set content-milestones
      { content-id: content-id, milestone-id: milestone-id }
      (merge milestone-data { total-achievers: (+ (get total-achievers milestone-data) u1) })
    )
    (map-set user-achievement-count
      { user: tx-sender }
      { total-badges: (+ (get total-badges user-stats) u1), total-value: (+ (get total-value user-stats) current-metric) }
    )
    (map-set milestone-leaderboard
      { content-id: content-id, milestone-id: milestone-id }
      {
        first-achiever: (if (is-none (get first-achiever leaderboard)) (some tx-sender) (get first-achiever leaderboard)),
        first-achieved-at: (if (is-none (get first-achieved-at leaderboard)) (some stacks-block-height) (get first-achieved-at leaderboard)),
        latest-achiever: (some tx-sender)
      }
    )
    (ok true)
  )
)

(define-read-only (get-milestone (content-id uint) (milestone-id uint))
  (map-get? content-milestones { content-id: content-id, milestone-id: milestone-id })
)

(define-read-only (get-user-achievement (user principal) (content-id uint) (milestone-id uint))
  (map-get? user-achievements { user: user, content-id: content-id, milestone-id: milestone-id })
)

(define-read-only (get-user-total-achievements (user principal))
  (map-get? user-achievement-count { user: user })
)

(define-read-only (get-milestone-leaderboard (content-id uint) (milestone-id uint))
  (map-get? milestone-leaderboard { content-id: content-id, milestone-id: milestone-id })
)

(define-read-only (check-milestone-eligibility (user principal) (content-id uint) (milestone-id uint) (metric-value uint))
  (let
    (
      (milestone-data (map-get? content-milestones { content-id: content-id, milestone-id: milestone-id }))
      (existing-achievement (map-get? user-achievements { user: user, content-id: content-id, milestone-id: milestone-id }))
    )
    (match milestone-data
      milestone-info
      (and
        (is-none existing-achievement)
        (>= metric-value (get threshold milestone-info))
        (get reward-enabled milestone-info)
      )
      false
    )
  )
)
