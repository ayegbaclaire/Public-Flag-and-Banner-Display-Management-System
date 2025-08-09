# Public Flag and Banner Display Management System

A comprehensive smart contract system for managing public displays including flags, banners, holiday decorations, and special event displays on government buildings and public spaces.

## System Overview

This system consists of five interconnected smart contracts that handle different aspects of public display management:

### 1. Flag Installation Coordination Contract (`flag-installation.clar`)
- Manages installation and positioning of flags on government buildings
- Tracks flag types, locations, and installation schedules
- Handles approval workflows for new flag installations

### 2. Holiday Decoration Management Contract (`holiday-decorations.clar`)
- Coordinates seasonal decorations and lighting displays
- Manages holiday decoration schedules and themes
- Tracks decoration inventory and installation status

### 3. Banner Permit Processing Contract (`banner-permits.clar`)
- Issues permits for banners and signs on public property
- Manages permit applications, approvals, and renewals
- Tracks permit compliance and violations

### 4. Maintenance and Replacement Contract (`maintenance-tracking.clar`)
- Monitors condition of flags, banners, and decorations
- Schedules maintenance and replacement activities
- Tracks maintenance costs and service providers

### 5. Special Event Decoration Contract (`event-decorations.clar`)
- Manages temporary decorations for parades, festivals, and celebrations
- Coordinates event-specific display requirements
- Handles setup and teardown scheduling

## Key Features

- **Decentralized Management**: Each contract operates independently while maintaining data consistency
- **Permission-Based Access**: Role-based permissions for different user types (administrators, contractors, citizens)
- **Audit Trail**: Complete tracking of all display-related activities
- **Cost Management**: Budget tracking and expense monitoring
- **Compliance Monitoring**: Automated compliance checking and violation tracking

## Contract Interactions

While contracts operate independently, they share common data structures and validation patterns:

- **Location Management**: Standardized location tracking across all contracts
- **Permission System**: Consistent role-based access control
- **Status Tracking**: Unified status management for all display items
- **Cost Tracking**: Standardized expense and budget management

## Getting Started

### Prerequisites
- Clarinet CLI installed
- Node.js and npm for testing
- Basic understanding of Clarity smart contracts

### Installation

1. Clone the repository
2. Install dependencies: `npm install`
3. Run tests: `npm test`
4. Deploy contracts: `clarinet deploy`

### Testing

The system includes comprehensive tests using Vitest:
- Unit tests for each contract function
- Integration tests for cross-contract scenarios
- Edge case testing for error conditions

### Usage Examples

#### Installing a New Flag
\`\`\`clarity
(contract-call? .flag-installation install-flag
"city-hall"
"american-flag"
u1640995200
"main-pole")
\`\`\`

#### Applying for Banner Permit
\`\`\`clarity
(contract-call? .banner-permits apply-for-permit
"welcome-banner"
"main-street"
u1640995200
u1641081600)
\`\`\`

#### Scheduling Holiday Decorations
\`\`\`clarity
(contract-call? .holiday-decorations schedule-decoration
"christmas-lights"
"downtown-square"
u1640995200
u1641081600)
\`\`\`

## Contract Architecture

Each contract follows a consistent pattern:
- **Data Maps**: Store primary entity data
- **Constants**: Define error codes and system limits
- **Private Functions**: Handle internal logic and validation
- **Public Functions**: Provide external interface
- **Read-Only Functions**: Allow data querying without state changes

## Security Considerations

- **Access Control**: All state-changing functions require appropriate permissions
- **Input Validation**: Comprehensive validation of all input parameters
- **Error Handling**: Detailed error codes for debugging and user feedback
- **State Consistency**: Atomic operations to maintain data integrity

## Future Enhancements

- Integration with IoT sensors for automated condition monitoring
- Mobile app integration for citizen reporting
- Advanced analytics and reporting dashboards
- Integration with city budget management systems
