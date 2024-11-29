;; EduVault - Decentralized Scholarship Fund with DAO Governance and Staking
;; A smart contract for managing and distributing educational scholarships with yield generation

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-not-eligible (err u102))
(define-constant err-already-disbursed (err u103))
(define-constant err-not-stakeholder (err u104))
(define-constant err-proposal-not-found (err u105))
(define-constant err-already-voted (err u106))
(define-constant err-proposal-ended (err u107))
(define-constant err-threshold-not-met (err u108))
(define-constant err-insufficient-stake (err u109))
(define-constant err-lock-period-active (err u110))

;; Data variables
(define-data-var minimum-donation uint u1000000) ;; In microSTX
(define-data-var required-gpa uint u300) ;; GPA multiplied by 100
(define-data-var required-attendance uint u85) ;; Percentage
(define-data-var proposal-duration uint u144) ;; ~24 hours in blocks
(define-data-var minimum-voting-power uint u1000000) ;; Minimum STX needed to vote
(define-data-var total-stakeholders uint u0)
(define-data-var next-proposal-id uint u0)
(define-data-var total-voting-power uint u0)
(define-data-var total-staked uint u0)
(define-data-var yield-rate uint u5) ;; 5% annual yield rate (can be adjusted via governance)
(define-data-var minimum-lock-period uint u52560) ;; Minimum staking period in blocks (~1 year)

;; Principal Maps
(define-map stakeholders
    principal
    {
        role: (string-ascii 20), ;; donor, educator, or alumni
        voting-power: uint,
        last-active: uint,
        total-donated: uint,
        staked-amount: uint,
        stake-start-block: uint,
        rewards-claimed: uint
    }
)

(define-map donors principal uint)

(define-map students 
    principal 
    {
        gpa: uint,
        attendance: uint,
        funds-received: uint,
        is-eligible: bool,
        graduation-year: uint
    }
)

(define-map scholarship-rounds 
    uint 
    {
        total-funds: uint,
        disbursed: bool,
        deadline: uint,
        round-criteria: {
            min-gpa: uint,
            min-attendance: uint,
            graduation-year: uint
        }
    }
)

;; Governance Structures
(define-map proposals
    uint
    {
        proposer: principal,
        proposal-type: (string-ascii 20),
        start-block: uint,
        end-block: uint,
        description: (string-ascii 500),
        value: uint,
        target-round: uint,
        executed: bool,
        votes-for: uint,
        votes-against: uint,
        quorum-reached: bool
    }
)

(define-map votes
    {proposal-id: uint, voter: principal}
    {vote: bool, weight: uint}
)

;; Staking Functions

(define-read-only (calculate-rewards (staked-amount uint) (blocks-staked uint))
    (let
        (
            (annual-blocks u52560) ;; Approximately number of blocks in a year
            (reward-rate (var-get yield-rate))
            (reward-multiplier (/ (* blocks-staked reward-rate) (* annual-blocks u100)))
        )
        (* staked-amount reward-multiplier)
    )
)

(define-public (stake-tokens (amount uint))
    (let
        (
            (current-stakeholder (unwrap! (map-get? stakeholders tx-sender) err-not-stakeholder))
            (current-stake (get staked-amount current-stakeholder))
        )
        (asserts! (>= amount (var-get minimum-donation)) err-invalid-amount)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (map-set stakeholders tx-sender
            (merge current-stakeholder
                {
                    staked-amount: (+ current-stake amount),
                    stake-start-block: block-height,
                    voting-power: (+ (get voting-power current-stakeholder) amount)
                }
            )
        )
        (var-set total-staked (+ (var-get total-staked) amount))
        (var-set total-voting-power (+ (var-get total-voting-power) amount))
        (ok true)
    )
)

(define-public (unstake-tokens (amount uint))
    (let
        (
            (current-stakeholder (unwrap! (map-get? stakeholders tx-sender) err-not-stakeholder))
            (current-stake (get staked-amount current-stakeholder))
            (stake-start (get stake-start-block current-stakeholder))
            (blocks-staked (- block-height stake-start))
        )
        (asserts! (>= current-stake amount) err-insufficient-stake)
        (asserts! (>= blocks-staked (var-get minimum-lock-period)) err-lock-period-active)
        
        ;; Calculate and distribute rewards
        (let
            (
                (rewards (calculate-rewards amount blocks-staked))
                (total-withdrawal (+ amount rewards))
            )
            (try! (as-contract (stx-transfer? total-withdrawal contract-owner tx-sender)))
            
            (map-set stakeholders tx-sender
                (merge current-stakeholder
                    {
                        staked-amount: (- current-stake amount),
                        rewards-claimed: (+ (get rewards-claimed current-stakeholder) rewards),
                        voting-power: (- (get voting-power current-stakeholder) amount)
                    }
                )
            )
            (var-set total-staked (- (var-get total-staked) amount))
            (var-set total-voting-power (- (var-get total-voting-power) amount))
            (ok total-withdrawal)
        )
    )
)

;; Public Functions - Stakeholder Management

(define-public (register-stakeholder (role (string-ascii 20)))
    (let
        (
            (current-donation (default-to u0 (map-get? donors tx-sender)))
        )
        (asserts! (>= current-donation (var-get minimum-donation)) err-invalid-amount)
        (map-set stakeholders tx-sender
            {
                role: role,
                voting-power: current-donation,
                last-active: block-height,
                total-donated: current-donation,
                staked-amount: u0,
                stake-start-block: u0,
                rewards-claimed: u0
            }
        )
        (var-set total-stakeholders (+ (var-get total-stakeholders) u1))
        (var-set total-voting-power (+ (var-get total-voting-power) current-donation))
        (ok true)
    )
)

;; Public Functions - Fund Management

(define-public (donate)
    (let
        (
            (donation-amount (stx-get-balance tx-sender))
            (current-stakeholder (map-get? stakeholders tx-sender))
        )
        (asserts! (>= donation-amount (var-get minimum-donation)) err-invalid-amount)
        (try! (stx-transfer? donation-amount tx-sender (as-contract tx-sender)))
        
        ;; Update donor records
        (map-set donors tx-sender 
            (+ donation-amount (default-to u0 (map-get? donors tx-sender)))
        )
        
        ;; Update stakeholder voting power if already registered
        (match current-stakeholder
            stakeholder-data
            (begin
                (var-set total-voting-power (+ (var-get total-voting-power) donation-amount))
                (map-set stakeholders tx-sender
                    (merge stakeholder-data
                        {
                            voting-power: (+ (get voting-power stakeholder-data) donation-amount),
                            total-donated: (+ (get total-donated stakeholder-data) donation-amount)
                        }
                    )
                )
            )
            true
        )
        (ok true)
    )
)

;; Public Functions - Student Management

(define-public (register-student (gpa uint) (attendance uint) (graduation-year uint))
    (begin
        (asserts! (and (>= gpa u0) (<= gpa u400)) err-invalid-amount)
        (asserts! (and (>= attendance u0) (<= attendance u100)) err-invalid-amount)
        (map-set students tx-sender
            {
                gpa: gpa,
                attendance: attendance,
                funds-received: u0,
                is-eligible: false,
                graduation-year: graduation-year
            }
        )
        (ok true)
    )
)

;; Public Functions - Governance

(define-public (create-proposal 
    (proposal-type (string-ascii 20))
    (description (string-ascii 500))
    (value uint)
    (target-round uint)
)
    (let
        (
            (proposer-info (unwrap! (map-get? stakeholders tx-sender) err-not-stakeholder))
            (proposal-id (var-get next-proposal-id))
        )
        (asserts! (>= (get voting-power proposer-info) (var-get minimum-voting-power)) err-not-eligible)
        
        (map-set proposals proposal-id
            {
                proposer: tx-sender,
                proposal-type: proposal-type,
                start-block: block-height,
                end-block: (+ block-height (var-get proposal-duration)),
                description: description,
                value: value,
                target-round: target-round,
                executed: false,
                votes-for: u0,
                votes-against: u0,
                quorum-reached: false
            }
        )
        
        (var-set next-proposal-id (+ proposal-id u1))
        (ok proposal-id)
    )
)

(define-public (cast-vote (proposal-id uint) (vote-for bool))
    (let
        (
            (proposal (unwrap! (map-get? proposals proposal-id) err-proposal-not-found))
            (voter-info (unwrap! (map-get? stakeholders tx-sender) err-not-stakeholder))
            (vote-key {proposal-id: proposal-id, voter: tx-sender})
        )
        (asserts! (not (is-some (map-get? votes vote-key))) err-already-voted)
        (asserts! (< block-height (get end-block proposal)) err-proposal-ended)
        
        (let
            (
                (vote-weight (get voting-power voter-info))
                (new-votes-for (if vote-for (+ (get votes-for proposal) vote-weight) (get votes-for proposal)))
                (new-votes-against (if (not vote-for) (+ (get votes-against proposal) vote-weight) (get votes-against proposal)))
                (total-votes (+ new-votes-for new-votes-against))
            )
            
            (map-set votes vote-key {vote: vote-for, weight: vote-weight})
            (map-set proposals proposal-id
                (merge proposal
                    {
                        votes-for: new-votes-for,
                        votes-against: new-votes-against,
                        quorum-reached: (>= total-votes (/ (var-get total-voting-power) u2))
                    }
                )
            )
            (ok true)
        )
    )
)

;; Read Only Functions

(define-read-only (get-proposal (proposal-id uint))
    (map-get? proposals proposal-id)
)

(define-read-only (get-stakeholder-info (address principal))
    (map-get? stakeholders address)
)

(define-read-only (get-student-info (address principal))
    (map-get? students address)
)

(define-read-only (get-vote (proposal-id uint) (voter principal))
    (map-get? votes {proposal-id: proposal-id, voter: voter})
)

(define-read-only (get-round-info (round-id uint))
    (map-get? scholarship-rounds round-id)
)

(define-read-only (get-total-voting-power)
    (var-get total-voting-power)
)

(define-read-only (get-pending-rewards (address principal))
    (let
        (
            (stakeholder-info (unwrap! (map-get? stakeholders address) (ok u0)))
            (current-stake (get staked-amount stakeholder-info))
            (stake-start (get stake-start-block stakeholder-info))
        )
        (if (> current-stake u0)
            (ok (calculate-rewards current-stake (- block-height stake-start)))
            (ok u0)
        )
    )
)