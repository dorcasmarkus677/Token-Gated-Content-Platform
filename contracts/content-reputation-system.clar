(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_RATED (err u102))
(define-constant ERR_ACCESS_DENIED (err u103))
(define-constant ERR_INVALID_RATING (err u104))

(define-map content-ratings
  { content-id: uint, rater: principal }
  { 
    rating: uint,
    review: (string-ascii 300),
    rated-at: uint,
    nft-token-id: uint
  }
)

(define-map content-rating-aggregate
  { content-id: uint }
  { 
    total-ratings: uint,
    sum-ratings: uint,
    five-star: uint,
    four-star: uint,
    three-star: uint,
    two-star: uint,
    one-star: uint
  }
)

(define-map creator-reputation
  { creator: principal }
  { 
    total-ratings: uint,
    average-rating: uint,
    total-reviews: uint
  }
)

(define-public (rate-content
  (content-id uint)
  (nft-token-id uint)
  (rating uint)
  (review (string-ascii 300))
)
  (let
    (
      (content-data (unwrap! (contract-call? .Token-Gated-Content-Platform get-content-info content-id) ERR_NOT_FOUND))
      (creator (get creator content-data))
      (can-access (contract-call? .Token-Gated-Content-Platform can-access-content tx-sender content-id nft-token-id))
      (existing-rating (map-get? content-ratings { content-id: content-id, rater: tx-sender }))
      (current-aggregate (default-to 
        { total-ratings: u0, sum-ratings: u0, five-star: u0, four-star: u0, three-star: u0, two-star: u0, one-star: u0 }
        (map-get? content-rating-aggregate { content-id: content-id })))
      (creator-rep (default-to { total-ratings: u0, average-rating: u0, total-reviews: u0 }
        (map-get? creator-reputation { creator: creator })))
    )
    (asserts! can-access ERR_ACCESS_DENIED)
    (asserts! (is-none existing-rating) ERR_ALREADY_RATED)
    (asserts! (and (>= rating u1) (<= rating u5)) ERR_INVALID_RATING)
    (map-set content-ratings
      { content-id: content-id, rater: tx-sender }
      { rating: rating, review: review, rated-at: stacks-block-height, nft-token-id: nft-token-id }
    )
    (let
      (
        (new-total (+ (get total-ratings current-aggregate) u1))
        (new-sum (+ (get sum-ratings current-aggregate) rating))
      )
      (map-set content-rating-aggregate
        { content-id: content-id }
        {
          total-ratings: new-total,
          sum-ratings: new-sum,
          five-star: (+ (get five-star current-aggregate) (if (is-eq rating u5) u1 u0)),
          four-star: (+ (get four-star current-aggregate) (if (is-eq rating u4) u1 u0)),
          three-star: (+ (get three-star current-aggregate) (if (is-eq rating u3) u1 u0)),
          two-star: (+ (get two-star current-aggregate) (if (is-eq rating u2) u1 u0)),
          one-star: (+ (get one-star current-aggregate) (if (is-eq rating u1) u1 u0))
        }
      )
      (map-set creator-reputation
        { creator: creator }
        {
          total-ratings: (+ (get total-ratings creator-rep) u1),
          average-rating: (/ (+ (* (get average-rating creator-rep) (get total-ratings creator-rep)) rating) new-total),
          total-reviews: (+ (get total-reviews creator-rep) u1)
        }
      )
    )
    (ok true)
  )
)

(define-read-only (get-content-rating (content-id uint) (rater principal))
  (map-get? content-ratings { content-id: content-id, rater: rater })
)

(define-read-only (get-content-rating-stats (content-id uint))
  (map-get? content-rating-aggregate { content-id: content-id })
)

(define-read-only (get-content-average-rating (content-id uint))
  (match (map-get? content-rating-aggregate { content-id: content-id })
    aggregate
    (ok (/ (get sum-ratings aggregate) (get total-ratings aggregate)))
    ERR_NOT_FOUND
  )
)

(define-read-only (get-creator-reputation (creator principal))
  (map-get? creator-reputation { creator: creator })
)
