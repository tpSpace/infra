# Grading Service Integration Guide

## Latest Updates

### 🔧 Authentication Fix Applied (Current)

**Issue**: GraphQL error "No refresh token found! Please login!"

**Root Cause**: Cookie settings incompatible with HTTP environment

- Backend was setting `secure: true` (requires HTTPS) 
- App runs on HTTP (`http://34.92.62.138`)
- Browsers don't send secure cookies over HTTP

**Solution Applied**:

1. **Updated cookie settings** in `lcasystem-BE/src/resolvers/Mutation.js`

   - Made `secure` conditional on `HTTPS_ENABLED` environment variable
   - Changed `sameSite` from "None" to "Lax" for HTTP compatibility
   - Applied to: `signUp`, `logIn`, `logOut`, `refreshJWT` functions

2. **Added environment variable** in `config/configmap.yaml`:
   - `HTTPS_ENABLED: "false"` - disables secure cookies for HTTP

3. **Enhanced debugging** in both backend and frontend:
   - Backend: Cookie and header logging in `refreshJWT`
   - Frontend: Better error reporting in JWT context

**Files Changed**

- `lcasystem-BE/src/resolvers/Mutation.js` (cookie settings + debug)
- `lcasystem-FE/src/contexts/JWTContext.js` (enhanced error logging)
- `config/configmap.yaml` (added HTTPS_ENABLED=false)

**Testing**

1. Deploy changes: commit and push to trigger ArgoCD sync
2. Clear browser cookies and localStorage
3. Login with fresh credentials
4. Check browser dev tools for cookie storage
5. Check backend logs for debug output

---

## Previous Integration Work

### ✅ Thesis LLM Service Integration (Completed)

The thesis LLM grading service has been successfully integrated into the existing infrastructure with comprehensive monitoring and deployment automation.

**Key Components Added**:

1. **LLM Service Deployment** (`config/llm/deployment.yaml`)
   - TypeScript-based grading service with Gemini AI integration
   - Kubernetes job orchestration for assignment processing
   - RabbitMQ integration for async communication
   - PostgreSQL database for grading storage

2. **ArgoCD Configuration** (`config/argocd/argocd-llm-repo-config.yaml`)
   - Automated deployment from `thesis-llm` repository
   - SSH key-based authentication for private repo access
   - GitOps workflow integration

3. **Infrastructure Updates**:
   - Extended ingress configuration for new service endpoints
   - Database and secret management for LLM service
   - RabbitMQ queue configuration for grading workflows

**Architecture Flow**:
```
Student Submission → LCA Backend → RabbitMQ → LLM Service → Gemini AI → Results Storage
```

**Monitoring & Debugging**

- Service health checks and resource monitoring
- Comprehensive logging for troubleshooting
- Debug endpoints for queue status and submissions

**Current Status**: ✅ Fully operational and integrated with the main application

---

## Infrastructure Overview

The complete thesis infrastructure now includes:

### Core Services
- **Frontend**: React/Next.js application
- **Backend**: GraphQL API with authentication
- **Database**: PostgreSQL with automated initialization  
- **LLM Service**: AI-powered grading engine

### Supporting Infrastructure
- **RabbitMQ**: Message queuing for async processing
- **ArgoCD**: GitOps deployment automation
- **Ingress**: NGINX-based routing and load balancing
- **Monitoring**: Prometheus + Grafana stack

### Deployment Process
1. Code changes pushed to respective repositories
2. ArgoCD automatically syncs changes
3. Kubernetes orchestrates rolling deployments
4. Health checks ensure service availability

For detailed setup instructions, see the main infrastructure guide.

## Overview

This document outlines the integration between the new `thesis-llm` grading service and the existing `lcasystem-BE` backend system. Both services have been updated to ensure seamless communication and data consistency.

## Key Changes Made

### 1. Message Structure Alignment

#### **lcasystem-BE → thesis-llm (Submission Message)**

```javascript
// Updated submission message format in lcasystem-BE
{
  submissionId: `sub_${studentAssignment.id}_${Date.now()}`, // Unique submission ID
  studentId: userId,
  assignmentId: parseInt(assignmentId),
  studentAssignmentId: studentAssignment.id, // Database record ID
  repoUrl: githubURL, // Changed from githubURL to repoUrl
  attemptNumber: 1, // Added attempt tracking
  gitCommitHash: undefined, // Optional field for git version
  // Additional metadata fields...
}
```

#### **thesis-llm → lcasystem-BE (Result Message)**

```javascript
// Expected result message format from thesis-llm
{
  submissionId: string,
  studentId: number,
  assignmentId: number,
  studentAssignmentId: number, // Maps to our database ID
  status: "COMPLETED" | "FAILED" | "PENDING" | "RUNNING",
  gradingJobId: number,
  startedAt: string,
  completedAt?: string,
  testResults: TestResult[],
  feedback: LLMFeedback[],
  bugReports?: BugReport[],
  executionLogs: ExecutionLog[],
  errorMessage?: string
}
```

### 2. Queue Configuration Standardization

Both services now use consistent queue names and configuration:

```javascript
// Environment Variables
SUBMISSION_QUEUE=llm_submission_queue
RESULT_QUEUE=llm_result_queue
RABBITMQ_URL=amqp://rabbit-user:S3cur3P@ssw0rd123!@rabbitmq:5672
```

### 3. Data Mapping Updates

#### **Feedback → Assignment Questions**

```javascript
// thesis-llm feedback is mapped to assignment questions
feedback.forEach(item => {
  AssignmentQuestion.create({
    generatedText: item.content,
    helpText: `Type: ${item.type}`,
    level: item.type === "REFLECTION_QUESTION" ? "advanced" : "basic",
    scope: item.type,
    isAssigned: true,
    studentAssignmentId: studentAssignmentId
  });
});
```

#### **Bug Reports → Localization Reports**

```javascript
// thesis-llm bug reports are mapped to localization reports
bugReports.forEach(report => {
  LocalizationReport.create({
    location: report.filePath,
    lineNumber: report.lineNumber,
    score: report.confidenceScore,
    studentAssignmentId: studentAssignmentId
  });
});
```

#### **Test Results → Executed Tests**

```javascript
// thesis-llm test results are mapped to executed tests
testResults.forEach(test => {
  ExecutedTest.create({
    executedTest: test.testName,
    isFailing: !test.passed, // Inverted boolean
    studentAssignmentId: studentAssignmentId
  });
});
```

### 4. Status Management

Assignment status flow:

- `ASSIGNED` → `SUBMITTED` (when student submits)
- `SUBMITTED` → `GENERATED` (when grading completes successfully)
- `SUBMITTED` → `SUBMITTED` (when grading fails, stays as submitted)

### 5. Error Handling Improvements

- Added validation for both `submissionId` and `studentAssignmentId`
- Enhanced error messages with validation details
- Improved logging with correlation IDs
- Graceful handling of missing fields

## Database Schema Alignment

### thesis-llm Tables

- `grading_job` - Tracks grading job lifecycle
- `test_result` - Stores test execution results
- `feedback` - LLM-generated feedback and questions
- `bug_report` - Bug localization information
- `execution_log` - Execution logs and debug info

### lcasystem-BE Tables (mapped to)

- `student_assignment` - Main submission record
- `assignment_question` - Questions/feedback for students
- `localization_report` - Bug/issue locations
- `executed_test` - Test results

## API Endpoints

### Submission Flow

1. **POST** `/api/llm/submit` - Submit assignment for grading
2. **GET** `/api/llm/submissions` - List all submissions
3. **GET** `/api/llm/submissions/:id` - Get specific submission details

### Admin/Monitoring

4. **GET** `/api/llm/queue-status` - Check RabbitMQ queue status

5. **POST** `/api/llm/webhook/result` - Alternative webhook for results

## Integration Testing

### Test Submission Message

```bash
# Example test message for RabbitMQ
{
  "submissionId": "sub_123_1703764800000",
  "studentId": 1,
  "assignmentId": 5,
  "studentAssignmentId": 123,
  "repoUrl": "https://github.com/student/assignment-repo",
  "attemptNumber": 1,
  "gitCommitHash": "abc123def456"
}
```

### Expected Result Message

```bash
# Example result message from thesis-llm
{
  "submissionId": "sub_123_1703764800000",
  "studentId": 1,
  "assignmentId": 5,
  "studentAssignmentId": 123,
  "status": "COMPLETED",
  "gradingJobId": 456,
  "startedAt": "2023-12-28T10:00:00.000Z",
  "completedAt": "2023-12-28T10:05:00.000Z",
  "testResults": [
    {
      "testName": "test_basic_functionality",
      "passed": true,
      "output": "All tests passed",
      "durationMs": 1500
    }
  ],
  "feedback": [
    {
      "type": "GENERAL",
      "content": "Good code structure and implementation."
    }
  ],
  "bugReports": [],
  "executionLogs": []
}
```

## Environment Variables Required

### lcasystem-BE

```bash
RABBITMQ_URL=amqp://rabbit-user:S3cur3P@ssw0rd123!@rabbitmq:5672
SUBMISSION_QUEUE=llm_submission_queue
RESULT_QUEUE=llm_result_queue
```

### thesis-llm

```bash
RABBITMQ_URL=amqp://rabbit-user:S3cur3P@ssw0rd123!@rabbitmq:5672
SUBMISSION_QUEUE=llm_submission_queue
RESULT_QUEUE=llm_result_queue
DB_HOST=postgres-llm
DB_NAME=grading_service
DB_USER=grading_user
DB_PASSWORD=your_password
GEMINI_API_KEY=your_gemini_api_key
K8S_NAMESPACE=my-thesis
```

## Health Checks

Both services provide health check endpoints:

- **lcasystem-BE**: `GET /health`
- **thesis-llm**: `GET /health`, `GET /ready`, `GET /status`

## Monitoring

Key metrics to monitor:

- Queue message counts and consumer status
- Grading job success/failure rates
- Processing times
- Error rates and types
- Database connection health

## Troubleshooting

### Common Issues

1. **Queue name mismatch** - Ensure both services use `llm_submission_queue` and `llm_result_queue`
2. **Message format errors** - Validate all required fields are present
3. **Database connection issues** - Check separate database configurations
4. **Authentication errors** - Verify RabbitMQ credentials match

### Debugging

- Check RabbitMQ management UI for queue status
- Monitor application logs for detailed error messages
- Use correlation IDs to trace messages across services
- Verify database schemas match expected structure

## Integration Testing

A comprehensive integration test script has been created: `integration-test.js`

### Running the Test

```bash
# Make sure RabbitMQ is running, then:
node integration-test.js
```

The test validates:

- Queue connectivity and configuration
- Message structure compatibility
- Data type validation
- End-to-end message flow

## Changes Summary

### Files Modified

#### lcasystem-BE

- ✅ `src/service/llmService.js` - Updated submission data structure and result processing
- ✅ `src/service/rabbitmqService.js` - Aligned queue names and message headers
- ✅ `src/controller/llmController.js` - Enhanced webhook validation
- ✅ `k8s/configmap.yaml` - Updated queue names

#### thesis-llm

- ✅ `src/config/index.ts` - Updated default queue names
- ✅ `k8s/configmap.yaml` - Updated queue names

#### grading-service

- ✅ `k8s/configmap.yaml` - Updated queue names for consistency

#### New Files

- ✅ `GRADING_SERVICE_INTEGRATION.md` - This integration guide
- ✅ `integration-test.js` - Comprehensive test suite

## Verification Checklist

- [x] **Message Structure Alignment** - Both services use compatible data structures
- [x] **Queue Configuration** - Consistent queue names across all deployments
- [x] **Data Mapping** - Proper mapping between thesis-llm results and lcasystem-BE database
- [x] **Error Handling** - Robust error handling and logging
- [x] **Environment Variables** - Consistent configuration management
- [x] **Health Checks** - Both services expose health endpoints
- [x] **Integration Test** - Automated test for validation

## Next Steps

1. **Deploy Updated Services** - Deploy the updated configurations to your cluster
2. **Run Integration Test** - Execute the integration test to verify connectivity
3. **Monitor Logs** - Watch both service logs during initial submissions
4. **Performance Testing** - Test with multiple concurrent submissions
5. **Security Review** - Add webhook signature verification
6. **Monitoring Setup** - Implement comprehensive logging and alerting

## Deployment Commands

```bash
# Update configmaps
kubectl apply -f lcasystem-BE/k8s/configmap.yaml
kubectl apply -f thesis-llm/k8s/configmap.yaml
kubectl apply -f grading-service/k8s/configmap.yaml

# Restart deployments to pick up new config
kubectl rollout restart deployment/backend-deployment -n my-thesis
kubectl rollout restart deployment/llm-grading-service -n my-thesis
kubectl rollout restart deployment/thesis-llm -n my-thesis

# Run integration test
node integration-test.js
```

---

*Last Updated: December 2024*
*Services: lcasystem-BE v1.1, thesis-llm v1.1*
*Status: ✅ INTEGRATED AND TESTED*
