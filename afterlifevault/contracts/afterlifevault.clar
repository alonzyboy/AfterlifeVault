;; AfterlifeVault - Multi-Chain Asset Distribution Protocol
;; Handles posthumous distribution of digital assets across blockchains

;; Traits
(define-trait token-nft
  (
    (transfer (uint principal principal) (response bool uint))
    (get-owner (uint) (response principal uint))
  )
)

(define-trait token-ft
  (
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    (get-balance (principal) (response uint uint))
  )
)

(define-trait bridge
  (
    (initiate-transfer ((string-ascii 64) principal uint) (response bool uint))
    (verify-transfer ((buff 32)) (response bool uint))
    (get-bridge-fee ((string-ascii 64)) (response uint uint))
  )
)

;; Constants
(define-constant admin tx-sender)
(define-constant ERR-UNAUTHORIZED (err u100))
(define-constant ERR-SETUP-COMPLETE (err u101))
(define-constant ERR-INVALID-HEIR (err u102))
(define-constant ERR-TRUSTEE-QUORUM (err u103))
(define-constant ERR-INACTIVE (err u104))
(define-constant ERR-CHAIN-INVALID (err u105))
(define-constant ERR-BRIDGE-FAIL (err u106))
(define-constant ERR-MAX-REACHED (err u107))
(define-constant ERR-NO-BRIDGE (err u108))
(define-constant MIN-TRUSTEES u2)

;; State Variables
(define-data-var checkpoint-height uint u0)
(define-data-var dormancy-period uint u0)
(define-data-var setup-complete bool false)
(define-data-var tx-count uint u0)

;; Storage Maps
(define-map heirs principal 
  {
    allocations: (list 200 {asset: (string-ascii 64), share: uint}),
    chain-accounts: (list 10 {network: (string-ascii 32), wallet: (string-ascii 64)})
  })
(define-map trustees principal bool)
(define-map trustee-votes principal uint)
(define-map networks 
  (string-ascii 32)
  {
    bridge-contract: principal,
    enabled: bool,
    blocks-needed: uint
  })
(define-map bridge-txs 
  (buff 32) 
  {
    heir: principal,
    network: (string-ascii 32),
    value: uint,
    state: (string-ascii 16)
  })

;; Helper Functions
(define-private (is-trustee (user principal))
  (default-to false (map-get? trustees user)))

(define-private (check-dormancy)
  (let ((current-height block-height))
    (if (> (- current-height (var-get checkpoint-height)) (var-get dormancy-period))
      true
      false)))

(define-private (validate-heir (heir principal))
  (match (map-get? heirs heir)
    heir-data true
    false))

(define-private (validate-network (network (string-ascii 32)))
  (match (map-get? networks network)
    network-data true
    false))

(define-private (get-bridge-contract (network (string-ascii 32)))
  (match (map-get? networks network)
    network-data (ok (get bridge-contract network-data))
    (err ERR-NO-BRIDGE)))

(define-private (create-tx-id)
  (let ((current-count (var-get tx-count)))
    (begin
      (var-set tx-count (+ current-count u1))
      (sha256 (concat (hash160 (print current-count)) (hash160 block-height))))))

;; Network Management
(define-public (configure-network 
    (network (string-ascii 32)) 
    (bridge-contract principal) 
    (blocks-needed uint)
    (enabled bool))
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (ok (map-set networks network {
      bridge-contract: bridge-contract,
      enabled: enabled,
      blocks-needed: blocks-needed
    }))))

;; Cross-Chain Functions
(define-public (add-chain-account 
    (heir principal) 
    (network (string-ascii 32)) 
    (wallet (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (asserts! (validate-network network) ERR-CHAIN-INVALID)
    (let ((existing-data (map-get? heirs heir)))
      (match existing-data
        data-value 
          (let ((new-account {network: network, wallet: wallet})
                (updated-accounts (unwrap! (as-max-len? 
                  (append (get chain-accounts data-value) new-account) 
                  u10) 
                  ERR-MAX-REACHED)))
            (ok (map-set heirs heir
              (merge data-value 
                {chain-accounts: updated-accounts}))))
        ERR-INVALID-HEIR))))

(define-public (verify-bridge-tx (tx-id (buff 32)))
  (match (map-get? bridge-txs tx-id)
    tx-data
      (ok (map-set bridge-txs tx-id
        (merge tx-data {state: "completed"})))
    (err ERR-BRIDGE-FAIL)))

;; Core Functions
(define-public (setup (period uint))
  (begin
    (asserts! (not (var-get setup-complete)) ERR-SETUP-COMPLETE)
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (var-set dormancy-period period)
    (var-set checkpoint-height block-height)
    (var-set setup-complete true)
    (ok true)))

(define-public (add-trustee (trustee principal))
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (ok (map-set trustees trustee true))))

(define-public (add-heir (heir principal) (allocation (list 200 {asset: (string-ascii 64), share: uint})))
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (ok (map-set heirs heir 
      {
        allocations: allocation,
        chain-accounts: (list)
      }))))

(define-public (ping)
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (ok (var-set checkpoint-height block-height))))

(define-public (vote-distribution (heir principal))
  (begin
    (asserts! (is-trustee tx-sender) ERR-UNAUTHORIZED)
    (asserts! (validate-heir heir) ERR-INVALID-HEIR)
    (asserts! (check-dormancy) ERR-INACTIVE)
    (ok (map-set trustee-votes tx-sender (+ (default-to u0 (map-get? trustee-votes tx-sender)) u1)))))

(define-public (process-distribution (heir principal))
  (let ((votes (default-to u0 (map-get? trustee-votes heir))))
    (begin
      (asserts! (>= votes MIN-TRUSTEES) ERR-TRUSTEE-QUORUM)
      (asserts! (check-dormancy) ERR-INACTIVE)
      (asserts! (validate-heir heir) ERR-INVALID-HEIR)
      (ok true))))

;; Asset Transfer Functions
(define-public (send-stx (heir principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (try! (stx-transfer? amount tx-sender heir))
    (ok true)))

(define-public (send-ft (token <token-ft>) (heir principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (try! (contract-call? token transfer amount tx-sender heir none))
    (ok true)))

(define-public (send-nft (token <token-nft>) (heir principal) (id uint))
  (begin
    (asserts! (is-eq tx-sender admin) ERR-UNAUTHORIZED)
    (try! (contract-call? token transfer id tx-sender heir))
    (ok true)))

;; Read-Only Functions
(define-read-only (get-last-ping)
  (ok (var-get checkpoint-height)))

(define-read-only (get-heir-allocation (heir principal))
  (ok (map-get? heirs heir)))

(define-read-only (get-trustee-status (user principal))
  (ok (is-trustee user)))

(define-read-only (get-network-info (network (string-ascii 32)))
  (ok (map-get? networks network)))

(define-read-only (get-bridge-status (tx-id (buff 32)))
  (ok (map-get? bridge-txs tx-id)))

(define-read-only (check-distribution-status (heir principal))
  (ok (and 
    (check-dormancy)
    (validate-heir heir)
    (>= (default-to u0 (map-get? trustee-votes heir)) MIN-TRUSTEES))))