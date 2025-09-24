;; AquaNet License Marketplace Contract
;; Enables trading of fishing licenses and maritime assets

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u6001))
(define-constant ERR-LISTING-NOT-FOUND (err u6002))
(define-constant ERR-INVALID-PRICE (err u6003))
(define-constant ERR-ALREADY-LISTED (err u6004))
(define-constant ERR-INSUFFICIENT-BALANCE (err u6005))
(define-constant ERR-EXPIRED-LISTING (err u6006))
(define-constant ERR-SELF-PURCHASE (err u6007))
(define-constant ERR-LISTING-INACTIVE (err u6008))
(define-constant ERR-INVALID-DURATION (err u6009))
(define-constant ERR-MARKETPLACE-CLOSED (err u6010))

;; Listing status constants
(define-constant LISTING-ACTIVE u0)
(define-constant LISTING-SOLD u1)
(define-constant LISTING-CANCELLED u2)
(define-constant LISTING-EXPIRED u3)

;; Asset type constants
(define-constant ASSET-FISHING-LICENSE u1)
(define-constant ASSET-BOAT-PERMIT u2)
(define-constant ASSET-QUOTA-SHARE u3)
(define-constant ASSET-EQUIPMENT u4)

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MARKETPLACE-FEE-PERCENT u250) ;; 2.5% fee
(define-constant MIN-LISTING-PRICE u10000) ;; Minimum 0.01 STX
(define-constant MAX-LISTING-DURATION u144000) ;; ~100 days in blocks
(define-constant BLOCKS-PER-DAY u144)

;; Data structures
(define-map marketplace-listings
  { listing-id: uint }
  {
    seller: principal,
    asset-type: uint,
    asset-id: uint,
    title: (string-ascii 100),
    description: (string-ascii 300),
    price: uint,
    listing-date: uint,
    expiry-date: uint,
    status: uint,
    category: (string-ascii 50),
    location: (string-ascii 50),
    condition: (string-ascii 20)
  }
)

(define-map user-listings
  { user: principal }
  { listing-ids: (list 100 uint) }
)

(define-map sale-records
  { sale-id: uint }
  {
    listing-id: uint,
    buyer: principal,
    seller: principal,
    sale-price: uint,
    marketplace-fee: uint,
    sale-date: uint,
    asset-type: uint,
    asset-id: uint
  }
)

(define-map category-stats
  { category: (string-ascii 50) }
  {
    total-listings: uint,
    total-sales: uint,
    avg-price: uint,
    last-sale-date: uint
  }
)

(define-map user-reputation
  { user: principal }
  {
    sales-completed: uint,
    purchases-made: uint,
    total-volume: uint,
    rating-sum: uint,
    rating-count: uint,
    join-date: uint
  }
)

;; Global state
(define-data-var next-listing-id uint u1)
(define-data-var next-sale-id uint u1)
(define-data-var total-listings uint u0)
(define-data-var total-sales uint u0)
(define-data-var total-volume uint u0)
(define-data-var marketplace-open bool true)
(define-data-var accumulated-fees uint u0)

;; Helper functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (calculate-marketplace-fee (price uint))
  (/ (* price MARKETPLACE-FEE-PERCENT) u10000)
)

(define-private (is-listing-owner (listing-id uint) (user principal))
  (match (map-get? marketplace-listings { listing-id: listing-id })
    listing (is-eq (get seller listing) user)
    false
  )
)

(define-private (is-listing-active (listing-id uint))
  (match (map-get? marketplace-listings { listing-id: listing-id })
    listing (and 
      (is-eq (get status listing) LISTING-ACTIVE)
      (< stacks-block-height (get expiry-date listing))
    )
    false
  )
)

(define-private (update-user-listings (user principal) (listing-id uint))
  (let (
    (current-listings (default-to { listing-ids: (list) } (map-get? user-listings { user: user })))
    (new-list (as-max-len? (append (get listing-ids current-listings) listing-id) u100))
  )
    (match new-list
      success (begin
        (map-set user-listings { user: user } { listing-ids: success })
        true
      )
      false
    )
  )
)

(define-private (update-category-stats (category (string-ascii 50)) (price uint) (is-sale bool))
  (let (
    (current-stats (default-to { total-listings: u0, total-sales: u0, avg-price: u0, last-sale-date: u0 }
                               (map-get? category-stats { category: category })))
    (new-listings (if is-sale (get total-listings current-stats) (+ (get total-listings current-stats) u1)))
    (new-sales (if is-sale (+ (get total-sales current-stats) u1) (get total-sales current-stats)))
  )
    (map-set category-stats { category: category }
      {
        total-listings: new-listings,
        total-sales: new-sales,
        avg-price: (if (> new-sales u0) (/ (+ (* (get avg-price current-stats) (get total-sales current-stats)) price) new-sales) u0),
        last-sale-date: (if is-sale stacks-block-height (get last-sale-date current-stats))
      }
    )
    true
  )
)

(define-private (initialize-user-reputation (user principal))
  (if (is-none (map-get? user-reputation { user: user }))
    (map-set user-reputation { user: user }
      {
        sales-completed: u0,
        purchases-made: u0,
        total-volume: u0,
        rating-sum: u0,
        rating-count: u0,
        join-date: stacks-block-height
      }
    )
    true
  )
)

;; Public functions
(define-public (create-listing
  (asset-type uint)
  (asset-id uint)
  (title (string-ascii 100))
  (description (string-ascii 300))
  (price uint)
  (duration-blocks uint)
  (category (string-ascii 50))
  (location (string-ascii 50))
  (condition (string-ascii 20))
)
  (let (
    (listing-id (var-get next-listing-id))
    (expiry-date (+ stacks-block-height duration-blocks))
  )
    (asserts! (var-get marketplace-open) ERR-MARKETPLACE-CLOSED)
    (asserts! (>= price MIN-LISTING-PRICE) ERR-INVALID-PRICE)
    (asserts! (<= duration-blocks MAX-LISTING-DURATION) ERR-INVALID-DURATION)
    (asserts! (> duration-blocks u0) ERR-INVALID-DURATION)
    
    ;; Initialize user reputation if needed
    (initialize-user-reputation tx-sender)
    
    ;; Create the listing
    (map-set marketplace-listings { listing-id: listing-id }
      {
        seller: tx-sender,
        asset-type: asset-type,
        asset-id: asset-id,
        title: title,
        description: description,
        price: price,
        listing-date: stacks-block-height,
        expiry-date: expiry-date,
        status: LISTING-ACTIVE,
        category: category,
        location: location,
        condition: condition
      }
    )
    
    ;; Update user listings
    (update-user-listings tx-sender listing-id)
    
    ;; Update category stats
    (update-category-stats category price false)
    
    ;; Update counters
    (var-set next-listing-id (+ listing-id u1))
    (var-set total-listings (+ (var-get total-listings) u1))
    
    (ok listing-id)
  )
)

(define-public (purchase-listing (listing-id uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
    (sale-price (get price listing))
    (marketplace-fee (calculate-marketplace-fee sale-price))
    (seller-amount (- sale-price marketplace-fee))
    (sale-id (var-get next-sale-id))
  )
    (asserts! (is-listing-active listing-id) ERR-LISTING-INACTIVE)
    (asserts! (not (is-eq tx-sender (get seller listing))) ERR-SELF-PURCHASE)
    
    ;; Initialize buyer reputation if needed
    (initialize-user-reputation tx-sender)
    
    ;; Transfer STX from buyer to seller
    (try! (stx-transfer? seller-amount tx-sender (get seller listing)))
    
    ;; Transfer marketplace fee to contract
    (try! (stx-transfer? marketplace-fee tx-sender CONTRACT-OWNER))
    
    ;; Update listing status
    (map-set marketplace-listings { listing-id: listing-id }
      (merge listing { status: LISTING-SOLD })
    )
    
    ;; Create sale record
    (map-set sale-records { sale-id: sale-id }
      {
        listing-id: listing-id,
        buyer: tx-sender,
        seller: (get seller listing),
        sale-price: sale-price,
        marketplace-fee: marketplace-fee,
        sale-date: stacks-block-height,
        asset-type: (get asset-type listing),
        asset-id: (get asset-id listing)
      }
    )
    
    ;; Update seller reputation
    (let (
      (seller-rep (default-to { sales-completed: u0, purchases-made: u0, total-volume: u0, rating-sum: u0, rating-count: u0, join-date: stacks-block-height }
                             (map-get? user-reputation { user: (get seller listing) })))
    )
      (map-set user-reputation { user: (get seller listing) }
        (merge seller-rep {
          sales-completed: (+ (get sales-completed seller-rep) u1),
          total-volume: (+ (get total-volume seller-rep) sale-price)
        })
      )
    )
    
    ;; Update buyer reputation
    (let (
      (buyer-rep (default-to { sales-completed: u0, purchases-made: u0, total-volume: u0, rating-sum: u0, rating-count: u0, join-date: stacks-block-height }
                            (map-get? user-reputation { user: tx-sender })))
    )
      (map-set user-reputation { user: tx-sender }
        (merge buyer-rep {
          purchases-made: (+ (get purchases-made buyer-rep) u1),
          total-volume: (+ (get total-volume buyer-rep) sale-price)
        })
      )
    )
    
    ;; Update category stats
    (update-category-stats (get category listing) sale-price true)
    
    ;; Update global counters
    (var-set next-sale-id (+ sale-id u1))
    (var-set total-sales (+ (var-get total-sales) u1))
    (var-set total-volume (+ (var-get total-volume) sale-price))
    (var-set accumulated-fees (+ (var-get accumulated-fees) marketplace-fee))
    
    (ok sale-id)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
  )
    (asserts! (is-listing-owner listing-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status listing) LISTING-ACTIVE) ERR-LISTING-INACTIVE)
    
    ;; Update listing status
    (map-set marketplace-listings { listing-id: listing-id }
      (merge listing { status: LISTING-CANCELLED })
    )
    
    (ok true)
  )
)

(define-public (update-listing-price (listing-id uint) (new-price uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
  )
    (asserts! (is-listing-owner listing-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-listing-active listing-id) ERR-LISTING-INACTIVE)
    (asserts! (>= new-price MIN-LISTING-PRICE) ERR-INVALID-PRICE)
    
    ;; Update listing price
    (map-set marketplace-listings { listing-id: listing-id }
      (merge listing { price: new-price })
    )
    
    (ok true)
  )
)

(define-public (extend-listing (listing-id uint) (additional-blocks uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
    (new-expiry (+ (get expiry-date listing) additional-blocks))
  )
    (asserts! (is-listing-owner listing-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-listing-active listing-id) ERR-LISTING-INACTIVE)
    (asserts! (<= (- new-expiry stacks-block-height) MAX-LISTING-DURATION) ERR-INVALID-DURATION)
    
    ;; Update listing expiry
    (map-set marketplace-listings { listing-id: listing-id }
      (merge listing { expiry-date: new-expiry })
    )
    
    (ok true)
  )
)

(define-public (rate-user (user principal) (rating uint))
  (let (
    (user-rep (unwrap! (map-get? user-reputation { user: user }) ERR-NOT-AUTHORIZED))
  )
    (asserts! (<= rating u5) ERR-INVALID-PRICE) ;; Rating from 1-5
    (asserts! (>= rating u1) ERR-INVALID-PRICE)
    (asserts! (not (is-eq tx-sender user)) ERR-SELF-PURCHASE)
    
    ;; Update user rating
    (map-set user-reputation { user: user }
      (merge user-rep {
        rating-sum: (+ (get rating-sum user-rep) rating),
        rating-count: (+ (get rating-count user-rep) u1)
      })
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-listing (listing-id uint))
  (map-get? marketplace-listings { listing-id: listing-id })
)

(define-read-only (get-user-listings (user principal))
  (map-get? user-listings { user: user })
)

(define-read-only (get-sale-record (sale-id uint))
  (map-get? sale-records { sale-id: sale-id })
)

(define-read-only (get-category-stats (category (string-ascii 50)))
  (map-get? category-stats { category: category })
)

(define-read-only (get-user-reputation (user principal))
  (match (map-get? user-reputation { user: user })
    rep (ok {
      sales-completed: (get sales-completed rep),
      purchases-made: (get purchases-made rep),
      total-volume: (get total-volume rep),
      average-rating: (if (> (get rating-count rep) u0)
                        (/ (get rating-sum rep) (get rating-count rep))
                        u0),
      rating-count: (get rating-count rep),
      join-date: (get join-date rep)
    })
    ERR-NOT-AUTHORIZED
  )
)

(define-read-only (get-marketplace-stats)
  {
    total-listings: (var-get total-listings),
    total-sales: (var-get total-sales),
    total-volume: (var-get total-volume),
    accumulated-fees: (var-get accumulated-fees),
    marketplace-open: (var-get marketplace-open),
    next-listing-id: (var-get next-listing-id)
  }
)

(define-read-only (calculate-fees (price uint))
  (calculate-marketplace-fee price)
)

(define-read-only (search-listings-by-category (category (string-ascii 50)))
  ;; This would need to be implemented with filtering logic
  ;; For now, return category stats
  (get-category-stats category)
)

;; Admin functions
(define-public (toggle-marketplace)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set marketplace-open (not (var-get marketplace-open)))
    (ok (var-get marketplace-open))
  )
)

(define-public (expire-listing (listing-id uint))
  (let (
    (listing (unwrap! (map-get? marketplace-listings { listing-id: listing-id }) ERR-LISTING-NOT-FOUND))
  )
    (asserts! (>= stacks-block-height (get expiry-date listing)) ERR-LISTING-INACTIVE)
    (asserts! (is-eq (get status listing) LISTING-ACTIVE) ERR-LISTING-INACTIVE)
    
    ;; Update listing status to expired
    (map-set marketplace-listings { listing-id: listing-id }
      (merge listing { status: LISTING-EXPIRED })
    )
    
    (ok true)
  )
)

