(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_ACCESS_DENIED (err u103))
(define-constant ERR_INSUFFICIENT_BALANCE (err u104))

(define-map content-tips
  { content-id: uint, tipper: principal }
  { amount: uint, tipped-at: uint }
)

(define-map creator-earnings
  { creator: principal }
  { total-earned: uint, total-tips: uint, last-withdrawal: uint }
)

(define-map tip-leaderboard
  { content-id: uint }
  { total-tips: uint, total-amount: uint, top-tipper: principal, top-tip-amount: uint }
)

(define-data-var platform-tip-fee uint u50)

(define-public (tip-content (content-id uint) (nft-token-id uint) (tip-amount uint))
  (let
    (
      (content-data (unwrap! (contract-call? .Token-Gated-Content-Platform get-content-info content-id) ERR_NOT_FOUND))
      (creator (get creator content-data))
      (nft-contract (get nft-contract content-data))
      (can-access (contract-call? .Token-Gated-Content-Platform can-access-content tx-sender content-id nft-token-id))
      (platform-fee (/ (* tip-amount (var-get platform-tip-fee)) u10000))
      (creator-amount (- tip-amount platform-fee))
      (current-earnings (default-to { total-earned: u0, total-tips: u0, last-withdrawal: u0 } 
        (map-get? creator-earnings { creator: creator })))
      (current-leaderboard (default-to { total-tips: u0, total-amount: u0, top-tipper: tx-sender, top-tip-amount: u0 }
        (map-get? tip-leaderboard { content-id: content-id })))
    )
    (asserts! (> tip-amount u0) ERR_INVALID_AMOUNT)
    (asserts! can-access ERR_ACCESS_DENIED)
    (asserts! (not (is-eq tx-sender creator)) ERR_UNAUTHORIZED)
    (try! (stx-transfer? creator-amount tx-sender creator))
    (map-set content-tips
      { content-id: content-id, tipper: tx-sender }
      { amount: tip-amount, tipped-at: stacks-block-height }
    )
    (map-set creator-earnings
      { creator: creator }
      { 
        total-earned: (+ (get total-earned current-earnings) creator-amount),
        total-tips: (+ (get total-tips current-earnings) u1),
        last-withdrawal: (get last-withdrawal current-earnings)
      }
    )
    (map-set tip-leaderboard
      { content-id: content-id }
      { 
        total-tips: (+ (get total-tips current-leaderboard) u1),
        total-amount: (+ (get total-amount current-leaderboard) tip-amount),
        top-tipper: (if (> tip-amount (get top-tip-amount current-leaderboard)) tx-sender (get top-tipper current-leaderboard)),
        top-tip-amount: (if (> tip-amount (get top-tip-amount current-leaderboard)) tip-amount (get top-tip-amount current-leaderboard))
      }
    )
    (ok tip-amount)
  )
)

(define-read-only (get-content-tip (content-id uint) (tipper principal))
  (map-get? content-tips { content-id: content-id, tipper: tipper })
)

(define-read-only (get-creator-earnings (creator principal))
  (map-get? creator-earnings { creator: creator })
)

(define-read-only (get-content-tip-stats (content-id uint))
  (map-get? tip-leaderboard { content-id: content-id })
)

(define-read-only (get-platform-tip-fee)
  (var-get platform-tip-fee)
)
