;; EduVault - Decentralized Scholarship Fund
;; A smart contract for managing and distributing educational scholarships

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-not-eligible (err u102))
(define-constant err-already-disbursed (err u103))

;; Data variables
(define-data-var minimum-donation uint u1000000) ;; In microSTX (1 STX = 1000000 microSTX)
(define-data-var required-gpa uint u300) ;; GPA multiplied by 100 (3.00 = 300)
(define-data-var required-attendance uint u85) ;; Percentage

;; Data maps
(define-map donors principal uint)
(define-map students 
    principal 
    {
        gpa: uint,
        attendance: uint,
        funds-received: uint,
        is-eligible: bool
    }
)

(define-map scholarship-rounds 
    uint 
    {
        total-funds: uint,
        disbursed: bool,
        deadline: uint
    }
)

;; Public functions

;; Function to donate to scholarship fund
(define-public (donate)
    (let
        (
            (amount (stx-get-balance tx-sender))
        )
        (if (>= amount (var-get minimum-donation))
            (begin
                (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
                (map-set donors tx-sender amount)
                (ok true)
            )
            err-invalid-amount
        )
    )
)

;; Register student with initial credentials
(define-public (register-student (gpa uint) (attendance uint))
    (begin
        (asserts! (and (>= gpa u0) (<= gpa u400)) err-invalid-amount)
        (asserts! (and (>= attendance u0) (<= attendance u100)) err-invalid-amount)
        (map-set students tx-sender {
            gpa: gpa,
            attendance: attendance,
            funds-received: u0,
            is-eligible: false
        })
        (ok true)
    )
)

;; Update student credentials (only contract owner can call)
(define-public (update-student-credentials (student principal) (new-gpa uint) (new-attendance uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (and (>= new-gpa u0) (<= new-gpa u400)) err-invalid-amount)
        (asserts! (and (>= new-attendance u0) (<= new-attendance u100)) err-invalid-amount)
        
        (match (map-get? students student)
            student-data
            (begin
                (map-set students student (merge student-data {
                    gpa: new-gpa,
                    attendance: new-attendance,
                    is-eligible: (and (>= new-gpa (var-get required-gpa)) 
                                    (>= new-attendance (var-get required-attendance)))
                }))
                (ok true)
            )
            err-not-eligible
        )
    )
)

;; Disburse scholarship to eligible student
(define-public (disburse-scholarship (student principal) (amount uint) (round-id uint))
    (let
        (
            (round (unwrap! (map-get? scholarship-rounds round-id) err-not-eligible))
            (student-data (unwrap! (map-get? students student) err-not-eligible))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (not (get disbursed round)) err-already-disbursed)
        (asserts! (get is-eligible student-data) err-not-eligible)
        
        (try! (as-contract (stx-transfer? amount tx-sender student)))
        (map-set scholarship-rounds round-id (merge round { disbursed: true }))
        (map-set students student (merge student-data {
            funds-received: (+ (get funds-received student-data) amount)
        }))
        (ok true)
    )
)

;; Read-only functions

;; Get student details
(define-read-only (get-student-info (student principal))
    (map-get? students student)
)

;; Get scholarship round details
(define-read-only (get-round-info (round-id uint))
    (map-get? scholarship-rounds round-id)
)

;; Get donor contribution
(define-read-only (get-donor-contribution (donor principal))
    (map-get? donors donor)
)