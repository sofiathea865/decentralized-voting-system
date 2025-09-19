;; Modern Stacks Smart Contract with Advanced Features
;; Comprehensive implementation with security and efficiency

;; ===========================================
;; ERROR CODES
;; ===========================================
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-PARAMS (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-PAUSED (err u105))

;; ===========================================
;; CONSTANTS
;; ===========================================
(define-constant CONTRACT-OWNER tx-sender)

;; ===========================================
;; DATA VARIABLES
;; ===========================================
(define-data-var contract-paused bool false)
(define-data-var total-records uint u0)
(define-data-var admin principal CONTRACT-OWNER)

;; ===========================================
;; DATA MAPS
;; ===========================================
(define-map Records
    { id: uint }
    {
        owner: principal,
        data-hash: (buff 32),
        timestamp: uint,
        status: (string-ascii 20),
        metadata: (string-utf8 256)
    }
)

(define-map Permissions
    { user: principal, resource: uint }
    { level: uint, granted-at: uint }
)

;; ===========================================
;; PRIVATE FUNCTIONS
;; ===========================================
(define-private (is-owner)
    (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (not-paused)
    (not (var-get contract-paused))
)

(define-private (get-next-id)
    (let ((current (var-get total-records)))
        (var-set total-records (+ current u1))
        (+ current u1)
    )
)

;; ===========================================
;; READ-ONLY FUNCTIONS
;; ===========================================
(define-read-only (get-contract-info)
    {
        owner: CONTRACT-OWNER,
        paused: (var-get contract-paused),
        total-records: (var-get total-records),
        admin: (var-get admin)
    }
)

(define-read-only (get-record (id uint))
    (map-get? Records { id: id })
)

(define-read-only (get-permission (user principal) (resource uint))
    (map-get? Permissions { user: user, resource: resource })
)

(define-read-only (has-permission (user principal) (resource uint) (level uint))
    (match (get-permission user resource)
        perm (>= (get level perm) level)
        false
    )
)

;; ===========================================
;; PUBLIC FUNCTIONS - ADMIN
;; ===========================================
(define-public (set-paused (paused bool))
    (begin
        (asserts! (is-owner) ERR-OWNER-ONLY)
        (var-set contract-paused paused)
        (ok paused)
    )
)

(define-public (set-admin (new-admin principal))
    (begin
        (asserts! (is-owner) ERR-OWNER-ONLY)
        (var-set admin new-admin)
        (ok new-admin)
    )
)

;; ===========================================
;; PUBLIC FUNCTIONS - CORE
;; ===========================================
(define-public (create-record (data-hash (buff 32)) (metadata (string-utf8 256)))
    (let ((id (get-next-id)))
        (asserts! (not-paused) ERR-PAUSED)
        (asserts! (> (len data-hash) u0) ERR-INVALID-PARAMS)
        
        (map-set Records
            { id: id }
            {
                owner: tx-sender,
                data-hash: data-hash,
                timestamp: stacks-block-height,
                status: "ACTIVE",
                metadata: metadata
            }
        )
        
        (map-set Permissions
            { user: tx-sender, resource: id }
            { level: u255, granted-at: stacks-block-height }
        )
        
        (ok id)
    )
)

(define-public (update-record (id uint) (new-metadata (string-utf8 256)))
    (let ((record (unwrap! (get-record id) ERR-NOT-FOUND)))
        (asserts! (not-paused) ERR-PAUSED)
        (asserts! (or (is-eq tx-sender (get owner record))
                     (has-permission tx-sender id u64)) ERR-NOT-AUTHORIZED)
        
        (map-set Records
            { id: id }
            (merge record { metadata: new-metadata })
        )
        
        (ok true)
    )
)

(define-public (grant-permission (user principal) (resource uint) (level uint))
    (let ((record (unwrap! (get-record resource) ERR-NOT-FOUND)))
        (asserts! (not-paused) ERR-PAUSED)
        (asserts! (is-eq tx-sender (get owner record)) ERR-NOT-AUTHORIZED)
        
        (map-set Permissions
            { user: user, resource: resource }
            { level: level, granted-at: stacks-block-height }
        )
        
        (ok true)
    )
)

(define-public (transfer-ownership (id uint) (new-owner principal))
    (let ((record (unwrap! (get-record id) ERR-NOT-FOUND)))
        (asserts! (not-paused) ERR-PAUSED)
        (asserts! (is-eq tx-sender (get owner record)) ERR-NOT-AUTHORIZED)
        
        (map-set Records
            { id: id }
            (merge record { owner: new-owner })
        )
        
        (map-set Permissions
            { user: new-owner, resource: id }
            { level: u255, granted-at: stacks-block-height }
        )
        
        (ok true)
    )
)

(define-public (deactivate-record (id uint))
    (let ((record (unwrap! (get-record id) ERR-NOT-FOUND)))
        (asserts! (not-paused) ERR-PAUSED)
        (asserts! (or (is-eq tx-sender (get owner record))
                     (is-eq tx-sender (var-get admin))) ERR-NOT-AUTHORIZED)
        
        (map-set Records
            { id: id }
            (merge record { status: "INACTIVE" })
        )
        
        (ok true)
    )
)

;; Emergency pause
(define-public (emergency-pause)
    (begin
        (asserts! (or (is-owner) (is-eq tx-sender (var-get admin))) ERR-NOT-AUTHORIZED)
        (var-set contract-paused true)
        (ok true)
    )
)
