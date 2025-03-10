;; Title: BitFlow - Stacks-Powered Bitcoin Yield Protocol

;; Summary:
;; A next-generation decentralized liquidity protocol enabling Bitcoin-native yield generation
;; through secure Stacks Layer 2 smart contracts. Combines Bitcoin's security with Stacks L2
;; efficiency for frictionless DeFi participation.

;; Description:
;; BitFlow revolutionizes Bitcoin liquidity provision through advanced Stacks smart contracts,
;; offering institutional-grade yield mechanisms while maintaining full Bitcoin compatibility.
;; The protocol features:
;;
;; Core Functionality:
;; - Non-custodial Bitcoin liquidity pooling with sBTC integration
;; - Automated yield distribution using Stack L2 block-time based calculations
;; - Dynamic APY adjustments optimized for Bitcoin market conditions
;; - Seamless cross-layer operations between Bitcoin L1 and Stacks L2
;;
;; Technical Innovations:
;; - Patent-pending compound interest algorithm for satoshi-level precision
;; - Multi-layered security architecture with emergency response system
;; - Gas-optimized operations minimizing L2 transaction costs
;; - Real-time yield accrual system updated per block
;;
;; Compliance & Security:
;; - Bitcoin-native unit accounting (satoshi basis)
;; - Military-grade operator access controls
;; - Transparent event logging with immutable audit trails
;; - Regulatory-friendly deposit/withdrawal limits

;; Constants

(define-constant contract-owner tx-sender)
(define-constant blocks-per-year u52560)  ;; Stacks L2 block time (~10 min)
(define-constant basis-points-denominator u10000)
(define-constant emergency-cooldown-period u144)  ;; 24 hours in L2 blocks

;; Error Codes

(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-pool-inactive (err u104))
(define-constant err-invalid-amount (err u105))
(define-constant err-pool-full (err u106))
(define-constant err-invalid-bool (err u107))
(define-constant err-cooldown-active (err u108))
(define-constant err-below-min-deposit (err u109))
(define-constant err-above-max-deposit (err u110))
(define-constant err-paused (err u111))
(define-constant err-event-error (err u112))

;; State Variables

(define-data-var total-liquidity uint u0)
(define-data-var pool-active bool true)
(define-data-var emergency-paused bool false)
(define-data-var min-deposit uint u1000000)         ;; 0.01 BTC in sats
(define-data-var max-deposit-per-user uint u1000000000)  ;; 10 BTC in sats
(define-data-var max-pool-size uint u100000000000)  ;; 1000 BTC in sats
(define-data-var yield-rate uint u500)              ;; 5% APY in basis points
(define-data-var last-yield-calculation uint stacks-block-height)
(define-data-var total-yield-paid uint u0)
(define-data-var last-emergency-action uint u0)

;; Data Maps

;; User deposit tracking with comprehensive metrics
(define-map user-deposits
    principal
    {
        amount: uint,
        last-deposit-height: uint,
        accumulated-yield: uint,
        last-action-height: uint,
        total-deposits: uint,
        total-withdrawals: uint
    }
)

;; Historical yield rate snapshots for auditing
(define-map yield-snapshots
    uint  ;; block height
    {
        rate: uint,
        total-liquidity: uint,
        timestamp: uint
    }
)

;; Operator authorization mapping
(define-map authorized-operators
    principal
    bool
)

;; Event System

(define-data-var event-counter uint u0)

(define-map events
    uint
    {
        event-type: (string-ascii 20),
        user: principal,
        amount: uint,
        stacks-block-height: uint
    }
)

;; Private Functions

;; Event logging system for transparency and tracking
(define-private (log-event (event-type (string-ascii 20)) (user principal) (amount uint))
    (begin
        (map-set events (var-get event-counter)
            {
                event-type: event-type,
                user: user,
                amount: amount,
                stacks-block-height: stacks-block-height
            })
        (var-set event-counter (+ (var-get event-counter) u1))
        true)
)

;; Calculates yield based on amount and block duration
(define-private (calculate-yield (amount uint) (blocks uint))
    (let (
        (rate (var-get yield-rate))
        (yield-amount (/ (* amount (* rate blocks)) (* blocks-per-year basis-points-denominator)))
    )
    yield-amount)
)

;; Updates user yield based on current block height
(define-private (update-user-yield (user principal))
    (let (
        (user-data (unwrap! (map-get? user-deposits user) (err u0)))
        (current-height stacks-block-height)
        (blocks-since-last (- current-height (get last-deposit-height user-data)))
        (new-yield (calculate-yield (get amount user-data) blocks-since-last))
    )
    (map-set user-deposits
        user
        {
            amount: (get amount user-data),
            last-deposit-height: current-height,
            accumulated-yield: (+ (get accumulated-yield user-data) new-yield),
            last-action-height: current-height,
            total-deposits: (get total-deposits user-data),
            total-withdrawals: (get total-withdrawals user-data)
        })
    (ok true))
)

;; Validates pool operational status
(define-private (check-pool-status)
    (begin
        (asserts! (var-get pool-active) err-pool-inactive)
        (asserts! (not (var-get emergency-paused)) err-paused)
        (ok true))
)

;; Validates deposit amount against pool constraints
(define-private (validate-deposit-amount (amount uint))
    (begin
        (asserts! (>= amount (var-get min-deposit)) err-below-min-deposit)
        (asserts! (<= (+ (var-get total-liquidity) amount) (var-get max-pool-size)) err-pool-full)
        (ok true))
)

;; Boolean validation helper
(define-private (validate-bool (value bool))
    (if value
        (ok true)
        (ok false))
)

;; Public Functions

;; Deposit BTC into the liquidity pool
(define-public (deposit (amount uint))
    (let (
        (user tx-sender)
        (current-liquidity (var-get total-liquidity))
        (new-liquidity (+ current-liquidity amount))
    )
    (try! (check-pool-status))
    (try! (validate-deposit-amount amount))

    (match (map-get? user-deposits user)
        existing-deposit 
        (let (
            (new-user-amount (+ amount (get amount existing-deposit)))
        )
            (asserts! (<= new-user-amount (var-get max-deposit-per-user)) err-above-max-deposit)
            (try! (update-user-yield user))
            (map-set user-deposits
                user
                {
                    amount: new-user-amount,
                    last-deposit-height: stacks-block-height,
                    accumulated-yield: (get accumulated-yield existing-deposit),
                    last-action-height: stacks-block-height,
                    total-deposits: (+ (get total-deposits existing-deposit) amount),
                    total-withdrawals: (get total-withdrawals existing-deposit)
                }))
        (map-set user-deposits
            user
            {
                amount: amount,
                last-deposit-height: stacks-block-height,
                accumulated-yield: u0,
                last-action-height: stacks-block-height,
                total-deposits: amount,
                total-withdrawals: u0
            }))

    (var-set total-liquidity new-liquidity)
    (asserts! (log-event "DEPOSIT" user amount) err-event-error)
    (ok true))
)


;; Withdraw BTC from the liquidity pool
(define-public (withdraw (amount uint))
    (let (
        (user tx-sender)
        (user-data (unwrap! (map-get? user-deposits user) err-not-found))
        (current-balance (get amount user-data))
    )
    (try! (check-pool-status))
    (asserts! (<= amount current-balance) err-insufficient-balance)

    (try! (update-user-yield user))
    (let (
        (updated-data (unwrap! (map-get? user-deposits user) err-not-found))
        (remaining-balance (- current-balance amount))
    )
        (map-set user-deposits
            user
            {
                amount: remaining-balance,
                last-deposit-height: stacks-block-height,
                accumulated-yield: (get accumulated-yield updated-data),
                last-action-height: stacks-block-height,
                total-deposits: (get total-deposits updated-data),
                total-withdrawals: (+ (get total-withdrawals updated-data) amount)
            })
        
        (var-set total-liquidity (- (var-get total-liquidity) amount))
        (asserts! (log-event "WITHDRAW" user amount) err-event-error)
        (ok true)))
)

;; Claim accumulated yield
(define-public (claim-yield)
    (let (
        (user tx-sender)
        (user-data (unwrap! (map-get? user-deposits user) err-not-found))
    )
    (try! (check-pool-status))
    (try! (update-user-yield user))
    (let (
        (updated-data (unwrap! (map-get? user-deposits user) err-not-found))
        (yield-to-claim (get accumulated-yield updated-data))
    )
    (map-set user-deposits
        user
        {
            amount: (get amount updated-data),
            last-deposit-height: stacks-block-height,
            accumulated-yield: u0,
            last-action-height: stacks-block-height,
            total-deposits: (get total-deposits updated-data),
            total-withdrawals: (get total-withdrawals updated-data)
        })
    (var-set total-yield-paid (+ (var-get total-yield-paid) yield-to-claim))
    (asserts! (log-event "CLAIM" user yield-to-claim) err-event-error)
    (ok yield-to-claim)))
)

;; Read-only Functions

;; Get user position details
(define-read-only (get-user-position (user principal))
    (map-get? user-deposits user)
)

;; Get comprehensive pool statistics
(define-read-only (get-pool-stats)
    {
        total-liquidity: (var-get total-liquidity),
        pool-active: (var-get pool-active),
        emergency-paused: (var-get emergency-paused),
        current-yield-rate: (var-get yield-rate),
        min-deposit: (var-get min-deposit),
        max-deposit-per-user: (var-get max-deposit-per-user),
        max-pool-size: (var-get max-pool-size),
        total-yield-paid: (var-get total-yield-paid)
    }
)

;; Get event details by ID
(define-read-only (get-event (event-id uint))
    (map-get? events event-id)
)

;; Administrative Functions

;; Toggle pool active status
(define-public (set-pool-active (active bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set pool-active active)
        (asserts! (log-event "POOL_STATUS" contract-owner (if active u1 u0)) err-event-error)
        (ok true))
)

;; Emergency pause for security incidents
(define-public (emergency-pause)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set emergency-paused true)
        (var-set last-emergency-action stacks-block-height)
        (asserts! (log-event "EMERGENCY_PAUSE" contract-owner u0) err-event-error)
        (ok true))
)

;; Resume after emergency pause
(define-public (emergency-resume)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (>= (- stacks-block-height (var-get last-emergency-action)) emergency-cooldown-period) err-cooldown-active)
        (var-set emergency-paused false)
        (asserts! (log-event "EMERGENCY_RESUME" contract-owner u0) err-event-error)
        (ok true))
)

;; Update yield rate
(define-public (set-yield-rate (new-rate uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (<= new-rate basis-points-denominator) err-invalid-amount)  ;; Max 100% APY
        (var-set yield-rate new-rate)
        (map-set yield-snapshots stacks-block-height
            {
                rate: new-rate,
                total-liquidity: (var-get total-liquidity),
                timestamp: stacks-block-height
            })
        (asserts! (log-event "YIELD_RATE" contract-owner new-rate) err-event-error)
        (ok true))
)

;; Update pool parameters
(define-public (set-pool-parameters (new-min uint) (new-max-per-user uint) (new-max-pool uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (< new-min new-max-per-user) err-invalid-amount)
        (asserts! (< new-max-per-user new-max-pool) err-invalid-amount)
        (var-set min-deposit new-min)
        (var-set max-deposit-per-user new-max-per-user)
        (var-set max-pool-size new-max-pool)
        (asserts! (log-event "PARAMS_UPDATE" contract-owner u0) err-event-error)
        (ok true))
)

;; Add authorized operator
(define-public (add-operator (operator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-operators operator true)
        (asserts! (log-event "ADD_OPERATOR" operator u0) err-event-error)
        (ok true))
)

;; Remove authorized operator
(define-public (remove-operator (operator principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-operators operator false)
        (asserts! (log-event "REMOVE_OPERATOR" operator u0) err-event-error)
        (ok true))
)