(define-constant ERR_GIFT_NOT_FOUND (err u200))
(define-constant ERR_GIFT_ALREADY_CLAIMED (err u201))
(define-constant ERR_INVALID_RECIPIENT (err u202))
(define-constant ERR_CANNOT_GIFT_TO_SELF (err u203))

(define-map gift-subscriptions
  { gift-id: uint }
  {
    gifter: principal,
    recipient: principal,
    plan-id: uint,
    message: (string-ascii 200),
    created-at: uint,
    is-claimed: bool,
    claimed-at: (optional uint)
  }
)

(define-data-var next-gift-id uint u1)

(define-public (gift-subscription
  (recipient principal)
  (plan-id uint)
  (message (string-ascii 200))
)
  (let
    (
      (gift-id (var-get next-gift-id))
      (plan-data (unwrap! (contract-call? .Content-Subscription-System get-subscription-plan plan-id) ERR_GIFT_NOT_FOUND))
      (price (get price plan-data))
      (creator (get creator plan-data))
      (platform-fee (/ (* price u200) u10000))
      (creator-amount (- price platform-fee))
    )
    (asserts! (not (is-eq tx-sender recipient)) ERR_CANNOT_GIFT_TO_SELF)
    (asserts! (get is-active plan-data) ERR_GIFT_NOT_FOUND)
    (try! (stx-transfer? creator-amount tx-sender creator))
    (map-set gift-subscriptions
      { gift-id: gift-id }
      {
        gifter: tx-sender,
        recipient: recipient,
        plan-id: plan-id,
        message: message,
        created-at: stacks-block-height,
        is-claimed: false,
        claimed-at: none
      }
    )
    (var-set next-gift-id (+ gift-id u1))
    (ok gift-id)
  )
)

(define-public (claim-gift-subscription (gift-id uint))
  (let
    (
      (gift-data (unwrap! (map-get? gift-subscriptions { gift-id: gift-id }) ERR_GIFT_NOT_FOUND))
      (plan-id (get plan-id gift-data))
      (existing-sub (contract-call? .Content-Subscription-System get-user-subscription tx-sender plan-id))
    )
    (asserts! (is-eq tx-sender (get recipient gift-data)) ERR_INVALID_RECIPIENT)
    (asserts! (not (get is-claimed gift-data)) ERR_GIFT_ALREADY_CLAIMED)
    (asserts! (is-none existing-sub) (err u104))
    (map-set gift-subscriptions
      { gift-id: gift-id }
      (merge gift-data { is-claimed: true, claimed-at: (some stacks-block-height) })
    )
    (ok true)
  )
)

(define-read-only (get-gift-info (gift-id uint))
  (map-get? gift-subscriptions { gift-id: gift-id })
)
