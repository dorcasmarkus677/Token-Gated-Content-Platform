(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_NFT (err u103))
(define-constant ERR_ACCESS_DENIED (err u104))

(define-map content-registry
  { content-id: uint }
  {
    creator: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    content-hash: (string-ascii 64),
    nft-contract: principal,
    created-at: uint,
    is-active: bool
  }
)

(define-map content-access-log
  { content-id: uint, accessor: principal }
  { accessed-at: uint, access-count: uint }
)

(define-map authorized-nft-contracts
  { contract-address: principal }
  { is-authorized: bool, added-by: principal, added-at: uint }
)

(define-map user-content-interactions
  { user: principal, content-id: uint }
  { interaction-type: (string-ascii 20), timestamp: uint, data: (string-ascii 200) }
)

(define-map nft-ownership-cache
  { nft-contract: principal, token-id: uint }
  { owner: principal, cached-at: uint }
)

(define-data-var next-content-id uint u1)
(define-data-var platform-fee-percentage uint u250)
(define-data-var total-content-count uint u0)

(define-public (authorize-nft-contract (nft-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-nft-contracts
      { contract-address: nft-contract }
      { is-authorized: true, added-by: tx-sender, added-at: stacks-block-height }
    ))
  )
)

(define-public (revoke-nft-contract (nft-contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set authorized-nft-contracts
      { contract-address: nft-contract }
      { is-authorized: false, added-by: tx-sender, added-at: stacks-block-height }
    ))
  )
)

(define-public (create-content 
  (title (string-ascii 100))
  (description (string-ascii 500))
  (content-hash (string-ascii 64))
  (nft-contract principal)
)
  (let
    (
      (content-id (var-get next-content-id))
      (nft-authorized (default-to false (get is-authorized (map-get? authorized-nft-contracts { contract-address: nft-contract }))))
    )
    (asserts! nft-authorized ERR_INVALID_NFT)
    (map-set content-registry
      { content-id: content-id }
      {
        creator: tx-sender,
        title: title,
        description: description,
        content-hash: content-hash,
        nft-contract: nft-contract,
        created-at: stacks-block-height,
        is-active: true
      }
    )
    (var-set next-content-id (+ content-id u1))
    (var-set total-content-count (+ (var-get total-content-count) u1))
    (ok content-id)
  )
)

(define-public (toggle-content-status (content-id uint))
  (let
    (
      (content-data (unwrap! (map-get? content-registry { content-id: content-id }) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator content-data)) ERR_UNAUTHORIZED)
    (ok (map-set content-registry
      { content-id: content-id }
      (merge content-data { is-active: (not (get is-active content-data)) })
    ))
  )
)

(define-public (register-nft-ownership (nft-contract principal) (token-id uint) (owner principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map-set nft-ownership-cache
      { nft-contract: nft-contract, token-id: token-id }
      { owner: owner, cached-at: stacks-block-height }
    ))
  )
)

(define-public (access-content (content-id uint) (nft-token-id uint))
  (let
    (
      (content-data (unwrap! (map-get? content-registry { content-id: content-id }) ERR_NOT_FOUND))
      (nft-contract (get nft-contract content-data))
      (current-access (default-to { accessed-at: u0, access-count: u0 } 
        (map-get? content-access-log { content-id: content-id, accessor: tx-sender })))
      (ownership-data (map-get? nft-ownership-cache { nft-contract: nft-contract, token-id: nft-token-id }))
    )
    (asserts! (get is-active content-data) ERR_ACCESS_DENIED)
    (asserts! (is-some ownership-data) ERR_INVALID_NFT)
    (asserts! (is-eq tx-sender (get owner (unwrap-panic ownership-data))) ERR_ACCESS_DENIED)
    (map-set content-access-log
      { content-id: content-id, accessor: tx-sender }
      { 
        accessed-at: stacks-block-height, 
        access-count: (+ (get access-count current-access) u1)
      }
    )
    (map-set user-content-interactions
      { user: tx-sender, content-id: content-id }
      { interaction-type: "access", timestamp: stacks-block-height, data: "content-viewed" }
    )
    (ok (get content-hash content-data))
  )
)

(define-public (interact-with-content 
  (content-id uint) 
  (nft-token-id uint)
  (interaction-type (string-ascii 20))
  (interaction-data (string-ascii 200))
)
  (let
    (
      (content-data (unwrap! (map-get? content-registry { content-id: content-id }) ERR_NOT_FOUND))
      (nft-contract (get nft-contract content-data))
      (ownership-data (map-get? nft-ownership-cache { nft-contract: nft-contract, token-id: nft-token-id }))
    )
    (asserts! (get is-active content-data) ERR_ACCESS_DENIED)
    (asserts! (is-some ownership-data) ERR_INVALID_NFT)
    (asserts! (is-eq tx-sender (get owner (unwrap-panic ownership-data))) ERR_ACCESS_DENIED)
    (ok (map-set user-content-interactions
      { user: tx-sender, content-id: content-id }
      { interaction-type: interaction-type, timestamp: stacks-block-height, data: interaction-data }
    ))
  )
)

(define-public (update-platform-fee (new-fee-percentage uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-fee-percentage u1000) ERR_UNAUTHORIZED)
    (ok (var-set platform-fee-percentage new-fee-percentage))
  )
)

(define-public (batch-register-ownership (registrations (list 50 { nft-contract: principal, token-id: uint, owner: principal })))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (ok (map register-single-ownership registrations))
  )
)

(define-private (register-single-ownership (registration { nft-contract: principal, token-id: uint, owner: principal }))
  (map-set nft-ownership-cache
    { nft-contract: (get nft-contract registration), token-id: (get token-id registration) }
    { owner: (get owner registration), cached-at: stacks-block-height }
  )
)

(define-read-only (get-content-info (content-id uint))
  (map-get? content-registry { content-id: content-id })
)

(define-read-only (get-content-access-stats (content-id uint) (accessor principal))
  (map-get? content-access-log { content-id: content-id, accessor: accessor })
)

(define-read-only (get-user-interaction (user principal) (content-id uint))
  (map-get? user-content-interactions { user: user, content-id: content-id })
)

(define-read-only (is-nft-contract-authorized (nft-contract principal))
  (default-to false (get is-authorized (map-get? authorized-nft-contracts { contract-address: nft-contract })))
)

(define-read-only (get-next-content-id)
  (var-get next-content-id)
)

(define-read-only (get-total-content-count)
  (var-get total-content-count)
)

(define-read-only (get-platform-fee-percentage)
  (var-get platform-fee-percentage)
)

(define-read-only (get-cached-nft-owner (nft-contract principal) (token-id uint))
  (map-get? nft-ownership-cache { nft-contract: nft-contract, token-id: token-id })
)

(define-read-only (can-access-content (user principal) (content-id uint) (nft-token-id uint))
  (let
    (
      (content-data (map-get? content-registry { content-id: content-id }))
    )
    (match content-data
      content-info
      (let
        (
          (nft-contract (get nft-contract content-info))
          (ownership-data (map-get? nft-ownership-cache { nft-contract: nft-contract, token-id: nft-token-id }))
        )
        (and 
          (get is-active content-info)
          (is-some ownership-data)
          (is-eq user (get owner (unwrap-panic ownership-data)))
        )
      )
      false
    )
  )
)

(define-read-only (get-content-by-creator (creator principal))
  (ok creator)
)

(define-read-only (verify-nft-ownership (user principal) (nft-contract principal) (nft-token-id uint))
  (let
    (
      (ownership-data (map-get? nft-ownership-cache { nft-contract: nft-contract, token-id: nft-token-id }))
    )
    (match ownership-data
      ownership-info
      (is-eq user (get owner ownership-info))
      false
    )
  )
)

(define-read-only (get-all-user-content-access (user principal))
  (ok user)
)

(define-read-only (get-content-stats (content-id uint))
  (let
    (
      (content-data (map-get? content-registry { content-id: content-id }))
    )
    (match content-data
      content-info
      (ok {
        creator: (get creator content-info),
        created-at: (get created-at content-info),
        is-active: (get is-active content-info),
        nft-contract: (get nft-contract content-info)
      })
      ERR_NOT_FOUND
    )
  )
)