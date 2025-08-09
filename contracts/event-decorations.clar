;; Special Event Decoration Contract
;; Manages temporary decorations for parades, festivals, and celebrations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-EVENT-NOT-FOUND (err u501))
(define-constant ERR-INVALID-DATES (err u502))
(define-constant ERR-INSUFFICIENT-BUDGET (err u503))
(define-constant ERR-LOCATION-CONFLICT (err u504))
(define-constant ERR-INVALID-EVENT-TYPE (err u505))
(define-constant ERR-SETUP-NOT-SCHEDULED (err u506))
(define-constant ERR-INVALID-STATUS (err u507))

;; Data Variables
(define-data-var next-event-id uint u1)
(define-data-var next-decoration-task-id uint u1)
(define-data-var event-budget uint u750000) ;; 750k microSTX
(define-data-var spent-event-budget uint u0)

;; Data Maps
(define-map special-events
  { event-id: uint }
  {
    event-name: (string-ascii 60),
    event-type: (string-ascii 30),
    organizer: principal,
    start-date: uint,
    end-date: uint,
    primary-location: (string-ascii 50),
    estimated-attendance: uint,
    decoration-budget: uint,
    status: (string-ascii 20),
    permit-required: bool
  }
)

(define-map event-decorations
  { event-id: uint, decoration-type: (string-ascii 40) }
  {
    location: (string-ascii 50),
    setup-date: uint,
    teardown-date: uint,
    decoration-cost: uint,
    setup-crew: principal,
    status: (string-ascii 20),
    special-requirements: (string-ascii 100),
    weather-dependent: bool
  }
)

(define-map decoration-tasks
  { task-id: uint }
  {
    event-id: uint,
    task-type: (string-ascii 30), ;; setup, maintenance, teardown
    assigned-crew: principal,
    scheduled-date: uint,
    completed-date: uint,
    task-duration: uint, ;; in hours
    labor-cost: uint,
    status: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

(define-map event-locations
  { location: (string-ascii 50), date-key: uint }
  {
    event-id: uint,
    reserved: bool,
    setup-start: uint,
    teardown-end: uint
  }
)

(define-map authorized-event-organizers
  { organizer: principal }
  {
    authorized: bool,
    organization: (string-ascii 50),
    budget-limit: uint,
    event-types-allowed: (string-ascii 100)
  }
)

(define-map decoration-crews
  { crew-lead: principal }
  {
    authorized: bool,
    crew-size: uint,
    specializations: (string-ascii 100),
    hourly-rate: uint,
    available: bool
  }
)

;; Private Functions
(define-private (is-authorized-organizer (organizer principal))
  (default-to false (get authorized (map-get? authorized-event-organizers { organizer: organizer })))
)

(define-private (get-organizer-budget-limit (organizer principal))
  (default-to u0 (get budget-limit (map-get? authorized-event-organizers { organizer: organizer })))
)

(define-private (is-authorized-crew (crew-lead principal))
  (default-to false (get authorized (map-get? decoration-crews { crew-lead: crew-lead })))
)

(define-private (has-location-conflict (location (string-ascii 50)) (start-date uint) (end-date uint))
  (let
    (
      (start-key (/ start-date u86400))
      (end-key (/ end-date u86400))
    )
    (or
      (is-some (map-get? event-locations { location: location, date-key: start-key }))
      (is-some (map-get? event-locations { location: location, date-key: end-key }))
    )
  )
)

(define-private (reserve-event-location (location (string-ascii 50)) (start-date uint) (end-date uint) (event-id uint) (setup-start uint) (teardown-end uint))
  (let
    (
      (start-key (/ start-date u86400))
      (end-key (/ end-date u86400))
    )
    (and
      (map-set event-locations
        { location: location, date-key: start-key }
        {
          event-id: event-id,
          reserved: true,
          setup-start: setup-start,
          teardown-end: teardown-end
        }
      )
      (map-set event-locations
        { location: location, date-key: end-key }
        {
          event-id: event-id,
          reserved: true,
          setup-start: setup-start,
          teardown-end: teardown-end
        }
      )
    )
  )
)

(define-private (calculate-setup-teardown-dates (event-start uint) (event-end uint))
  {
    setup-start: (- event-start u86400), ;; 1 day before event
    teardown-end: (+ event-end u86400)   ;; 1 day after event
  }
)

;; Public Functions
(define-public (authorize-event-organizer (organizer principal) (organization (string-ascii 50)) (budget-limit uint) (event-types (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> budget-limit u0) ERR-INSUFFICIENT-BUDGET)

    (ok (map-set authorized-event-organizers
      { organizer: organizer }
      {
        authorized: true,
        organization: organization,
        budget-limit: budget-limit,
        event-types-allowed: event-types
      }
    ))
  )
)

(define-public (authorize-decoration-crew (crew-lead principal) (crew-size uint) (specializations (string-ascii 100)) (hourly-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> crew-size u0) ERR-INVALID-EVENT-TYPE)
    (asserts! (> hourly-rate u0) ERR-INSUFFICIENT-BUDGET)

    (ok (map-set decoration-crews
      { crew-lead: crew-lead }
      {
        authorized: true,
        crew-size: crew-size,
        specializations: specializations,
        hourly-rate: hourly-rate,
        available: true
      }
    ))
  )
)

(define-public (create-special-event (event-name (string-ascii 60)) (event-type (string-ascii 30)) (start-date uint) (end-date uint) (primary-location (string-ascii 50)) (estimated-attendance uint) (decoration-budget uint))
  (let
    (
      (event-id (var-get next-event-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (organizer-limit (get-organizer-budget-limit tx-sender))
      (current-spent (var-get spent-event-budget))
      (total-budget (var-get event-budget))
      (dates (calculate-setup-teardown-dates start-date end-date))
    )
    (asserts! (is-authorized-organizer tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> start-date current-time) ERR-INVALID-DATES)
    (asserts! (> end-date start-date) ERR-INVALID-DATES)
    (asserts! (<= decoration-budget organizer-limit) ERR-INSUFFICIENT-BUDGET)
    (asserts! (<= (+ current-spent decoration-budget) total-budget) ERR-INSUFFICIENT-BUDGET)
    (asserts! (not (has-location-conflict primary-location start-date end-date)) ERR-LOCATION-CONFLICT)

    (map-set special-events
      { event-id: event-id }
      {
        event-name: event-name,
        event-type: event-type,
        organizer: tx-sender,
        start-date: start-date,
        end-date: end-date,
        primary-location: primary-location,
        estimated-attendance: estimated-attendance,
        decoration-budget: decoration-budget,
        status: "planned",
        permit-required: (> estimated-attendance u500)
      }
    )

    (reserve-event-location
      primary-location
      start-date
      end-date
      event-id
      (get setup-start dates)
      (get teardown-end dates)
    )

    (var-set next-event-id (+ event-id u1))
    (var-set spent-event-budget (+ current-spent decoration-budget))
    (ok event-id)
  )
)

(define-public (add-event-decoration (event-id uint) (decoration-type (string-ascii 40)) (location (string-ascii 50)) (decoration-cost uint) (special-requirements (string-ascii 100)) (weather-dependent bool))
  (let
    (
      (event (unwrap! (map-get? special-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (setup-date (- (get start-date event) u86400))
      (teardown-date (+ (get end-date event) u86400))
    )
    (asserts! (is-eq tx-sender (get organizer event)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status event) "planned") ERR-INVALID-STATUS)
    (asserts! (> decoration-cost u0) ERR-INSUFFICIENT-BUDGET)

    (ok (map-set event-decorations
      { event-id: event-id, decoration-type: decoration-type }
      {
        location: location,
        setup-date: setup-date,
        teardown-date: teardown-date,
        decoration-cost: decoration-cost,
        setup-crew: tx-sender, ;; Will be assigned later
        status: "planned",
        special-requirements: special-requirements,
        weather-dependent: weather-dependent
      }
    ))
  )
)

(define-public (assign-decoration-crew (event-id uint) (decoration-type (string-ascii 40)) (crew-lead principal))
  (let
    (
      (event (unwrap! (map-get? special-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (decoration (unwrap! (map-get? event-decorations { event-id: event-id, decoration-type: decoration-type }) ERR-EVENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get organizer event)) ERR-NOT-AUTHORIZED)
    (asserts! (is-authorized-crew crew-lead) ERR-NOT-AUTHORIZED)

    (ok (map-set event-decorations
      { event-id: event-id, decoration-type: decoration-type }
      (merge decoration { setup-crew: crew-lead })
    ))
  )
)

(define-public (schedule-decoration-task (event-id uint) (task-type (string-ascii 30)) (assigned-crew principal) (scheduled-date uint) (task-duration uint) (labor-cost uint))
  (let
    (
      (task-id (var-get next-decoration-task-id))
      (event (unwrap! (map-get? special-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq tx-sender (get organizer event)) ERR-NOT-AUTHORIZED)
    (asserts! (is-authorized-crew assigned-crew) ERR-NOT-AUTHORIZED)
    (asserts! (> scheduled-date current-time) ERR-INVALID-DATES)
    (asserts! (> task-duration u0) ERR-INVALID-DATES)

    (map-set decoration-tasks
      { task-id: task-id }
      {
        event-id: event-id,
        task-type: task-type,
        assigned-crew: assigned-crew,
        scheduled-date: scheduled-date,
        completed-date: u0,
        task-duration: task-duration,
        labor-cost: labor-cost,
        status: "scheduled",
        notes: ""
      }
    )

    (var-set next-decoration-task-id (+ task-id u1))
    (ok task-id)
  )
)

(define-public (complete-decoration-task (task-id uint) (notes (string-ascii 200)))
  (let
    (
      (task (unwrap! (map-get? decoration-tasks { task-id: task-id }) ERR-EVENT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (is-eq tx-sender (get assigned-crew task)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status task) "scheduled") ERR-INVALID-STATUS)

    (ok (map-set decoration-tasks
      { task-id: task-id }
      (merge task {
        completed-date: current-time,
        status: "completed",
        notes: notes
      })
    ))
  )
)

(define-public (update-event-status (event-id uint) (new-status (string-ascii 20)))
  (let
    (
      (event (unwrap! (map-get? special-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get organizer event)) ERR-NOT-AUTHORIZED)

    (ok (map-set special-events
      { event-id: event-id }
      (merge event { status: new-status })
    ))
  )
)

;; Read-Only Functions
(define-read-only (get-special-event (event-id uint))
  (map-get? special-events { event-id: event-id })
)

(define-read-only (get-event-decoration (event-id uint) (decoration-type (string-ascii 40)))
  (map-get? event-decorations { event-id: event-id, decoration-type: decoration-type })
)

(define-read-only (get-decoration-task (task-id uint))
  (map-get? decoration-tasks { task-id: task-id })
)

(define-read-only (get-organizer-info (organizer principal))
  (map-get? authorized-event-organizers { organizer: organizer })
)

(define-read-only (get-crew-info (crew-lead principal))
  (map-get? decoration-crews { crew-lead: crew-lead })
)

(define-read-only (check-location-availability (location (string-ascii 50)) (start-date uint) (end-date uint))
  (not (has-location-conflict location start-date end-date))
)

(define-read-only (get-event-budget-status)
  {
    total-budget: (var-get event-budget),
    spent-budget: (var-get spent-event-budget),
    remaining-budget: (- (var-get event-budget) (var-get spent-event-budget))
  }
)

(define-read-only (get-next-event-id)
  (var-get next-event-id)
)

(define-read-only (get-next-task-id)
  (var-get next-decoration-task-id)
)
