(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_SUBSCRIPTION_EXPIRED (err u103))
(define-constant ERR_ALREADY_SUBSCRIBED (err u104))

(define-map subscription-plans
  { plan-id: uint }
  { 
    creator: principal,
    name: (string-ascii 50),
    price: uint,
    duration-blocks: uint,
    max-subscribers: uint,
    current-subscribers: uint,
    is-active: bool
  }
)

(define-map user-subscriptions
  { subscriber: principal, plan-id: uint }
  { subscribed-at: uint, expires-at: uint, auto-renew: bool }
)

(define-map creator-subscription-revenue
  { creator: principal }
  { total-revenue: uint, active-subscribers: uint, total-subscribers: uint }
)

(define-data-var next-plan-id uint u1)
(define-data-var platform-subscription-fee uint u200)

(define-public (create-subscription-plan 
  (name (string-ascii 50))
  (price uint)
  (duration-blocks uint)
  (max-subscribers uint)
)
  (let
    (
      (plan-id (var-get next-plan-id))
    )
    (asserts! (> price u0) ERR_INVALID_AMOUNT)
    (asserts! (> duration-blocks u0) ERR_INVALID_AMOUNT)
    (map-set subscription-plans
      { plan-id: plan-id }
      {
        creator: tx-sender,
        name: name,
        price: price,
        duration-blocks: duration-blocks,
        max-subscribers: max-subscribers,
        current-subscribers: u0,
        is-active: true
      }
    )
    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)
  )
)

(define-public (subscribe-to-plan (plan-id uint))
  (let
    (
      (plan-data (unwrap! (map-get? subscription-plans { plan-id: plan-id }) ERR_NOT_FOUND))
      (creator (get creator plan-data))
      (price (get price plan-data))
      (duration (get duration-blocks plan-data))
      (current-subs (get current-subscribers plan-data))
      (max-subs (get max-subscribers plan-data))
      (expires-at (+ stacks-block-height duration))
      (platform-fee (/ (* price (var-get platform-subscription-fee)) u10000))
      (creator-amount (- price platform-fee))
      (existing-sub (map-get? user-subscriptions { subscriber: tx-sender, plan-id: plan-id }))
      (creator-revenue (default-to { total-revenue: u0, active-subscribers: u0, total-subscribers: u0 }
        (map-get? creator-subscription-revenue { creator: creator })))
    )
    (asserts! (get is-active plan-data) ERR_NOT_FOUND)
    (asserts! (< current-subs max-subs) ERR_INVALID_AMOUNT)
    (asserts! (is-none existing-sub) ERR_ALREADY_SUBSCRIBED)
    (try! (stx-transfer? creator-amount tx-sender creator))
    (map-set user-subscriptions
      { subscriber: tx-sender, plan-id: plan-id }
      { subscribed-at: stacks-block-height, expires-at: expires-at, auto-renew: false }
    )
    (map-set subscription-plans
      { plan-id: plan-id }
      (merge plan-data { current-subscribers: (+ current-subs u1) })
    )
    (map-set creator-subscription-revenue
      { creator: creator }
      {
        total-revenue: (+ (get total-revenue creator-revenue) creator-amount),
        active-subscribers: (+ (get active-subscribers creator-revenue) u1),
        total-subscribers: (+ (get total-subscribers creator-revenue) u1)
      }
    )
    (ok expires-at)
  )
)

(define-read-only (get-subscription-plan (plan-id uint))
  (map-get? subscription-plans { plan-id: plan-id })
)

(define-read-only (get-user-subscription (subscriber principal) (plan-id uint))
  (map-get? user-subscriptions { subscriber: subscriber, plan-id: plan-id })
)

(define-read-only (is-subscription-active (subscriber principal) (plan-id uint))
  (match (map-get? user-subscriptions { subscriber: subscriber, plan-id: plan-id })
    subscription-data
    (> (get expires-at subscription-data) stacks-block-height)
    false
  )
)

(define-read-only (get-creator-revenue (creator principal))
  (map-get? creator-subscription-revenue { creator: creator })
)