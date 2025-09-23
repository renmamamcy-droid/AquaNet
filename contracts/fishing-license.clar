;; AquaNet Fishing License Contract
;; Manages the issuance and lifecycle of fishing licenses as NFTs

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u5001))
(define-constant ERR-LICENSE-NOT-FOUND (err u5002))
(define-constant ERR-INVALID-AMOUNT (err u5003))
(define-constant ERR-LICENSE-EXPIRED (err u5004))
(define-constant ERR-QUOTA-EXCEEDED (err u5005))
(define-constant ERR-INVALID-LOCATION (err u5006))
(define-constant ERR-LICENSE-SUSPENDED (err u5007))
(define-constant ERR-ALREADY-ISSUED (err u5008))
(define-constant ERR-INVALID-DURATION (err u5009))
(define-constant ERR-INSUFFICIENT-FEE (err u5010))

;; License status constants
(define-constant STATUS-ACTIVE u0)
(define-constant STATUS-EXPIRED u1)
(define-constant STATUS-SUSPENDED u2)
(define-constant STATUS-TRANSFERRED u3)
(define-constant STATUS-RENEWED u4)

;; License type constants
(define-constant TYPE-COMMERCIAL u1)
(define-constant TYPE-RECREATIONAL u2)
(define-constant TYPE-CHARTER u3)
(define-constant TYPE-RESEARCH u4)

;; Contract constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-QUOTA u1000000) ;; Maximum catch quota
(define-constant MIN-LICENSE-FEE u100000) ;; 0.1 STX minimum fee
(define-constant BLOCKS-PER-YEAR u52560) ;; ~1 year in blocks
(define-constant MAX-LICENSE-DURATION (* u5 BLOCKS-PER-YEAR)) ;; 5 years max

;; Data structures
(define-map fishing-licenses
  { license-id: uint }
  {
    owner: principal,
    license-type: uint,
    fishing-zone: (string-ascii 50),
    species-allowed: (string-ascii 100),
    quota-limit: uint,
    quota-used: uint,
    issue-date: uint,
    expiry-date: uint,
    license-fee: uint,
    status: uint,
    renewable: bool,
    restrictions: (string-ascii 200)
  }
)

(define-map license-ownership
  { owner: principal }
  { license-ids: (list 50 uint) }
)

(define-map license-activity
  { license-id: uint, activity-date: uint }
  {
    catch-amount: uint,
    location: (string-ascii 50),
    species-caught: (string-ascii 50),
    reported-by: principal
  }
)

(define-map zone-regulations
  { zone-name: (string-ascii 50) }
  {
    max-daily-quota: uint,
    restricted-species: (string-ascii 100),
    seasonal-restrictions: (string-ascii 100),
    min-license-type: uint
  }
)

;; Global state
(define-data-var next-license-id uint u1)
(define-data-var total-licenses-issued uint u0)
(define-data-var total-revenue uint u0)
(define-data-var contract-paused bool false)

;; Helper functions
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-license-owner (license-id uint) (user principal))
  (match (map-get? fishing-licenses { license-id: license-id })
    license (is-eq (get owner license) user)
    false
  )
)

(define-private (is-license-active (license-id uint))
  (match (map-get? fishing-licenses { license-id: license-id })
    license (and 
      (is-eq (get status license) STATUS-ACTIVE)
      (< stacks-block-height (get expiry-date license))
    )
    false
  )
)

(define-private (calculate-license-fee (license-type uint) (duration-blocks uint))
  (let (
    (base-fee (if (is-eq license-type TYPE-COMMERCIAL)
                u1000000  ;; 1 STX for commercial
                u500000)) ;; 0.5 STX for recreational
    (duration-multiplier (/ duration-blocks BLOCKS-PER-YEAR))
    (multiplier (if (>= duration-multiplier u1) duration-multiplier u1))
  )
    (* base-fee multiplier)
  )
)

(define-private (update-license-ownership (owner principal) (license-id uint))
  (let (
    (current-licenses (default-to { license-ids: (list) } (map-get? license-ownership { owner: owner })))
    (new-list (as-max-len? (append (get license-ids current-licenses) license-id) u50))
  )
    (match new-list
      success (begin
        (map-set license-ownership { owner: owner } { license-ids: success })
        true
      )
      false
    )
  )
)

;; Public functions
(define-public (issue-fishing-license
  (license-type uint)
  (fishing-zone (string-ascii 50))
  (species-allowed (string-ascii 100))
  (quota-limit uint)
  (duration-blocks uint)
  (restrictions (string-ascii 200))
)
  (let (
    (license-id (var-get next-license-id))
    (current-block stacks-block-height)
    (expiry-date (+ current-block duration-blocks))
    (license-fee (calculate-license-fee license-type duration-blocks))
  )
    (asserts! (not (var-get contract-paused)) (err u999))
    (asserts! (>= license-fee MIN-LICENSE-FEE) ERR-INSUFFICIENT-FEE)
    (asserts! (<= duration-blocks MAX-LICENSE-DURATION) ERR-INVALID-DURATION)
    (asserts! (<= quota-limit MAX-QUOTA) ERR-QUOTA-EXCEEDED)
    (asserts! (or (is-eq license-type TYPE-COMMERCIAL)
                  (is-eq license-type TYPE-RECREATIONAL)
                  (is-eq license-type TYPE-CHARTER)
                  (is-eq license-type TYPE-RESEARCH)) ERR-INVALID-AMOUNT)
    
    ;; Create the fishing license
    (map-set fishing-licenses { license-id: license-id }
      {
        owner: tx-sender,
        license-type: license-type,
        fishing-zone: fishing-zone,
        species-allowed: species-allowed,
        quota-limit: quota-limit,
        quota-used: u0,
        issue-date: current-block,
        expiry-date: expiry-date,
        license-fee: license-fee,
        status: STATUS-ACTIVE,
        renewable: true,
        restrictions: restrictions
      }
    )
    
    ;; Update ownership tracking
    (update-license-ownership tx-sender license-id)
    
    ;; Update counters
    (var-set next-license-id (+ license-id u1))
    (var-set total-licenses-issued (+ (var-get total-licenses-issued) u1))
    (var-set total-revenue (+ (var-get total-revenue) license-fee))
    
    (ok license-id)
  )
)

(define-public (renew-license (license-id uint) (duration-blocks uint))
  (let (
    (license (unwrap! (map-get? fishing-licenses { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
    (renewal-fee (calculate-license-fee (get license-type license) duration-blocks))
  )
    (asserts! (is-license-owner license-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (get renewable license) ERR-NOT-AUTHORIZED)
    (asserts! (<= duration-blocks MAX-LICENSE-DURATION) ERR-INVALID-DURATION)
    
    ;; Update license with new expiry date
    (map-set fishing-licenses { license-id: license-id }
      (merge license {
        expiry-date: (+ stacks-block-height duration-blocks),
        license-fee: renewal-fee,
        status: STATUS-RENEWED
      })
    )
    
    ;; Update revenue
    (var-set total-revenue (+ (var-get total-revenue) renewal-fee))
    
    (ok true)
  )
)

(define-public (report-catch
  (license-id uint)
  (catch-amount uint)
  (location (string-ascii 50))
  (species-caught (string-ascii 50))
)
  (let (
    (license (unwrap! (map-get? fishing-licenses { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
    (new-quota-used (+ (get quota-used license) catch-amount))
  )
    (asserts! (is-license-owner license-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-license-active license-id) ERR-LICENSE-EXPIRED)
    (asserts! (<= new-quota-used (get quota-limit license)) ERR-QUOTA-EXCEEDED)
    
    ;; Record the catch activity
    (map-set license-activity { license-id: license-id, activity-date: stacks-block-height }
      {
        catch-amount: catch-amount,
        location: location,
        species-caught: species-caught,
        reported-by: tx-sender
      }
    )
    
    ;; Update license quota usage
    (map-set fishing-licenses { license-id: license-id }
      (merge license { quota-used: new-quota-used })
    )
    
    (ok true)
  )
)

(define-public (transfer-license (license-id uint) (new-owner principal))
  (let (
    (license (unwrap! (map-get? fishing-licenses { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
  )
    (asserts! (is-license-owner license-id tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-license-active license-id) ERR-LICENSE-EXPIRED)
    
    ;; Update license ownership
    (map-set fishing-licenses { license-id: license-id }
      (merge license {
        owner: new-owner,
        status: STATUS-TRANSFERRED
      })
    )
    
    ;; Update ownership tracking for new owner
    (update-license-ownership new-owner license-id)
    
    (ok true)
  )
)

(define-public (suspend-license (license-id uint))
  (let (
    (license (unwrap! (map-get? fishing-licenses { license-id: license-id }) ERR-LICENSE-NOT-FOUND))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (map-set fishing-licenses { license-id: license-id }
      (merge license { status: STATUS-SUSPENDED })
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-fishing-license (license-id uint))
  (map-get? fishing-licenses { license-id: license-id })
)

(define-read-only (get-user-licenses (owner principal))
  (map-get? license-ownership { owner: owner })
)

(define-read-only (get-license-activity (license-id uint) (activity-date uint))
  (map-get? license-activity { license-id: license-id, activity-date: activity-date })
)

(define-read-only (check-license-validity (license-id uint))
  (match (map-get? fishing-licenses { license-id: license-id })
    license (ok {
      valid: (and (is-eq (get status license) STATUS-ACTIVE)
                 (< stacks-block-height (get expiry-date license))),
      quota-remaining: (- (get quota-limit license) (get quota-used license)),
      expires-in: (- (get expiry-date license) stacks-block-height)
    })
    ERR-LICENSE-NOT-FOUND
  )
)

(define-read-only (get-zone-regulations (zone-name (string-ascii 50)))
  (map-get? zone-regulations { zone-name: zone-name })
)

(define-read-only (get-contract-stats)
  {
    next-license-id: (var-get next-license-id),
    total-licenses-issued: (var-get total-licenses-issued),
    total-revenue: (var-get total-revenue),
    contract-paused: (var-get contract-paused)
  }
)

;; Admin functions
(define-public (set-zone-regulations
  (zone-name (string-ascii 50))
  (max-daily-quota uint)
  (restricted-species (string-ascii 100))
  (seasonal-restrictions (string-ascii 100))
  (min-license-type uint)
)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (map-set zone-regulations { zone-name: zone-name }
      {
        max-daily-quota: max-daily-quota,
        restricted-species: restricted-species,
        seasonal-restrictions: seasonal-restrictions,
        min-license-type: min-license-type
      }
    )
    
    (ok true)
  )
)

(define-public (toggle-contract-pause)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-paused (not (var-get contract-paused)))
    (ok (var-get contract-paused))
  )
)


