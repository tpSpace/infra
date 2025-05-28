# Chapter 3: Methodology

## 3.1 System Architecture Overview

The system implements a modern cloud-native microservices architecture designed for bug localization services in learner code analysis. Built on Google Kubernetes Engine (GKE), the architecture follows a typical four-tier pattern:

1. **Frontend Service**: A Next.js-based web application providing the user interface for students and instructors
2. **Backend Service**: A GraphQL API service that handles the core bug localization logic and data processing
3. **Database Service**: A PostgreSQL database for persistent storage of code submissions and analysis results
4. **Grading Service**: A Python-based microservice that clones learner code via Kubernetes jobs, compiles and executes code, and uses an LLM to generate feedback and questions, communicating asynchronously with the backend via RabbitMQ.

The system embraces GitOps principles through ArgoCD, ensuring infrastructure and application changes follow a consistent, versioned, and automated deployment process.

![System Architecture Diagram](architecture-diagram.png)

```text
+----------------------------------+
| Users (Students, Instructors)    |
+----------------------------------+
            | (HTTPS)
            v
+----------------------------------+
| Internet                         |
+----------------------------------+
            | 
            v
+----------------------------------+    +----------------------------------+
| GKE Cluster (us-central1)        |    | GCP Services                     |
|                                  |    | (Monitoring, Logging, Vertex AI) |
|  +----------------------------+  |    +----------------------------------+
|  | Namespace: my-thesis       |  |              ^ (Metrics, Logs)
|  |                            |  |              |
|  |  +---------------------+   |  |              |
|  |  | Nginx Ingress       |   |  |              |
|  |  | (Routing, Load Bal.)|   |  |              |
|  |  +---------------------+   |  |              |
|  |      | /      | /api       |  |              |
|  |      v        v            |  |              |
|  |  +---------------------+   |  |              |
|  |  | Next.js Frontend    |   |  |              |
|  |  | (2 replicas)        |   |  |              |
|  |  +---------------------+   |  |              |
|  |      | (GraphQL)           |  |              |
|  |      v                     |  |              |
|  |  +---------------------+   |  |              |
|  |  | GraphQL Backend     |   |  |              |
|  |  | (3 replicas, HPA)   |   |  |              |
|  |  +---------------------+   |  |              |
|  |      | (RabbitMQ)           |  |              |
|  |      v                     |  |              |
|  |  +---------------------+   |  |              |
|  |  | RabbitMQ Broker     |   |  |              |
|  |  +---------------------+   |  |              |
|  |      | (Message Queue)     |   |  |              |
|  |      v                     |   |  |              |
|  |  +---------------------+   |  |              |
|  |  | Grading Service     |   |  |              |
|  |  | (Python, 1 replica) |   |  |              |
|  |  +---------------------+   |  |              |
|  |      | (K8s Job & LLM)       |  |              |
|  |      v                     |  |              |
|  |  +---------------------+   |  |              |
|  |  | PostgreSQL          |   |  |              |
|  |  | (10Gi PVC)          |   |  |              |
|  |  +---------------------+   |  |              |
|  +----------------------------+  |              |
|                                  |              |
|  +----------------------------+  |              |
|  | Namespace: argocd          |  |              |
|  |  +---------------------+   |  |              |
|  |  | ArgoCD (GitOps)     |   |  |              |
|  |  +---------------------+   |  |              |
|  +----------------------------+  |              |
+----------------------------------+              |
            ^ (Image Pull)                        |
            |                                     |
+----------------------------------+              |
| GHCR (Images)                    |<-------------+
+----------------------------------+
            ^ (CI/CD)
            |
+---------------------------------+
| Git Repos (infra, thesis-fe,     |
| thesis-be)                       |<-------------+
+----------------------------------+ (GitOps Sync)
Scalability: 1000 users
Real-time Feedback: <5s
Gemini Accuracy: 80-90%-
```

### 3.1.1 Infrastructure Components

The infrastructure leverages several key components that work together to create a robust, scalable, and maintainable system:

- **Google Kubernetes Engine (GKE)**: Google's managed Kubernetes service that provides a secure, production-ready environment for containerized applications. GKE offers several advantages for this implementation:
  - **Automated node upgrades and repairs**: Reduces maintenance overhead by automatically handling node updates and fixing unhealthy nodes
  - **Multi-zone and regional clusters**: Ensures high availability by distributing workloads across multiple zones
  - **Integration with Google Cloud services**: Seamless connectivity with other Google Cloud services like Cloud Monitoring, Cloud Logging, and Identity and Access Management (IAM)
  - **Release channels**: Ability to choose between rapid, regular, or stable release channels for Kubernetes version updates
  - **Auto-scaling capabilities**: Dynamic adjustment of cluster resources based on workload demands

- **Nginx Ingress Controller**: An open-source Kubernetes ingress controller that manages external access to services within the cluster:
  - **Advanced traffic routing**: Supports path-based routing, allowing different services to be accessed through different URL paths
  - **SSL/TLS termination**: Handles HTTPS connections and certificate management
  - **Load balancing**: Distributes incoming traffic across multiple service instances
  - **Rate limiting and throttling**: Protects backend services from traffic spikes
  - **Session persistence**: Maintains user sessions for stateful applications
  - **Customizable configurations**: Allows fine-tuning of connection parameters, timeouts, and buffer sizes
  - **WebSocket support**: Essential for real-time communication in modern web applications

- **ArgoCD**: A declarative, GitOps continuous delivery tool for Kubernetes that automates the deployment of applications:
  - **Declarative application definitions**: Applications are defined as Kubernetes manifests stored in Git repositories
  - **Automated synchronization**: Continuously monitors Git repositories and applies changes to the cluster
  - **Multi-cluster deployment**: Can deploy applications across multiple Kubernetes clusters
  - **Role-Based Access Control (RBAC)**: Granular access control for different teams and environments
  - **Rollback capabilities**: Easy rollback to previous application versions
  - **Web UI and CLI**: Multiple interfaces for monitoring and managing deployments
  - **SSO integration**: Support for enterprise authentication systems
  - **Webhook integration**: Triggers deployments based on external events
  - **Health assessment**: Built-in application health monitoring

- **PostgreSQL**: A powerful, open-source object-relational database system with over 30 years of active development:
  - **ACID compliance**: Ensures data integrity through Atomicity, Consistency, Isolation, and Durability
  - **Complex query optimization**: Advanced query planner for efficient execution of complex queries
  - **JSON support**: Native storage and querying of JSON data, useful for storing varied code analysis results
  - **Extensibility**: Custom data types, operators, and functions can be added
  - **Full-text search**: Built-in capabilities for searching through code and analysis results
  - **Concurrency**: Multi-Version Concurrency Control (MVCC) for high performance in multi-user environments
  - **Replication**: Supports both synchronous and asynchronous replication for high availability
  - **Partitioning**: Table partitioning for improved performance with large datasets
  - **Kubernetes integration**: Well-supported in Kubernetes environments through StatefulSets

- **GitHub Container Registry (GHCR)**: GitHub's container registry service that integrates directly with GitHub repositories:
  - **Seamless GitHub integration**: Direct connection to GitHub repositories and actions
  - **Fine-grained permissions**: Container access can be managed at the organization, repository, or team level
  - **Vulnerability scanning**: Automatic scanning of container images for security vulnerabilities
  - **Versioned image tags**: Support for semantic versioning of container images
  - **Package visibility controls**: Public, private, and internal visibility options
  - **GitHub Actions integration**: Automated workflows for building and publishing containers
  - **Image metadata**: Rich metadata support for container images
  - **Image deletion and cleanup policies**: Management of container lifecycle

- **Next.js**: A React framework for building server-side rendered and static web applications:
  - **Server-side rendering (SSR)**: Improves performance and SEO by rendering pages on the server
  - **Static site generation (SSG)**: Pre-renders pages at build time for optimal performance
  - **Automatic code splitting**: Loads only the JavaScript needed for each page
  - **API routes**: Built-in API endpoints for backend functionality
  - **TypeScript support**: First-class support for type safety
  - **Hot module replacement**: Instant feedback during development
  - **Image optimization**: Automatic image optimization and responsive sizing
  - **Internationalization**: Built-in support for multiple languages

- **GraphQL**: A query language and runtime for APIs that enables clients to request exactly the data they need:
  - **Declarative data fetching**: Clients specify exactly what data they need
  - **Single endpoint**: All data accessible through a single API endpoint
  - **Strong typing**: Schema-defined types for all data
  - **Introspection**: Self-documenting API that can be explored
  - **Real-time updates**: Subscription support for live data
  - **Batched queries**: Multiple data requirements resolved in a single request
  - **Versioning-free**: Evolve the API without version numbers
  - **Detailed error messages**: Precise feedback on query issues

- **RabbitMQ**: An open-source message broker used for asynchronous communication between the GraphQL backend and the gradient service, decoupling services and improving scalability and reliability.
- **Prometheus**: An open-source monitoring and alerting toolkit used to collect metrics and logs from application services and infrastructure, providing real-time observability and alerting capabilities.

## 3.2 DevOps and GitOps Methodology

### 3.2.1 Infrastructure as Code (IaC)

The entire infrastructure is defined using Terraform, a powerful open-source Infrastructure as Code (IaC) tool developed by HashiCorp. Terraform enables declarative infrastructure provisioning across multiple cloud providers and services. For this implementation, Terraform manages all aspects of the Google Cloud Platform resources, ensuring consistency, reproducibility, and maintainability:

```terraform
# GKE Cluster
resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = var.node_count
  deletion_protection      = false
}

# Node Pool with autoscaling
resource "google_container_node_pool" "node_pool" {
  name       = "app-node-pool"
  cluster    = google_container_cluster.gke.id
  location   = google_container_cluster.gke.location
  
  autoscaling {
    min_node_count = 2
    max_node_count = 5
  }
  # Additional configuration...
}
```

This Infrastructure as Code approach provides numerous benefits:

- **Version Control**: All infrastructure changes are tracked in Git, providing a complete history of infrastructure evolution, facilitating collaboration, and enabling rollbacks to previous states when necessary.

- **Reproducibility**: Environments can be consistently recreated across development, staging, and production with minimal manual intervention. This ensures parity between environments and reduces "works on my machine" problems.

- **Documentation**: The code serves as self-documenting architecture, making it easier for new team members to understand the infrastructure and reducing the need for separate documentation that can become outdated.

- **Automation**: Reduces manual intervention and human error in infrastructure provisioning through automated workflows. Changes can be applied systematically and predictably.

- **State Management**: Terraform maintains a state file that tracks the current state of all managed resources, allowing it to determine what changes need to be made to reach the desired state.

- **Dependency Resolution**: Automatically handles resource dependencies, ensuring resources are created, updated, or destroyed in the correct order.

- **Modularization**: Infrastructure code can be organized into reusable modules, promoting DRY (Don't Repeat Yourself) principles and consistency across projects.

- **Plan and Apply Workflow**: Terraform's plan phase shows what changes will be made before they are applied, providing an opportunity for review and reducing the risk of unexpected changes.

Terraform manages a wide range of resources in this implementation:

- **Kubernetes Cluster**: Provisioning and configuration of the GKE cluster
- **Node Pools**: Configuration of worker nodes with appropriate machine types and autoscaling settings
- **Networking**: VPC configuration, subnets, and firewall rules
- **IAM**: Service accounts and permissions for secure operation
- **Kubernetes Resources**: Initial setup of namespaces, secrets, and core services
- **Helm Releases**: Deployment of Nginx Ingress Controller and other Helm-based applications

The Terraform workflow is integrated into the CI/CD pipeline, allowing infrastructure changes to be tested and applied automatically when code is merged to the main branch, further reinforcing the GitOps methodology.

### 3.2.2 GitOps Implementation with ArgoCD

The GitOps methodology is implemented through ArgoCD, a declarative continuous delivery tool built specifically for Kubernetes. ArgoCD embodies the core GitOps principles by using Git repositories as the single source of truth for defining the desired application state. The implementation provides a robust, automated deployment pipeline:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: thesis-backend
  namespace: argocd
spec:
  project: thesis
  source:
    repoURL: git@github.com:tpSpace/infra.git
    targetRevision: HEAD
    path: be
  destination:
    server: https://kubernetes.default.svc
    namespace: my-thesis
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      # Additional configuration...
```

This GitOps implementation provides several key advantages:

- **Declarative Configuration**: All application deployments are defined as YAML manifests stored in Git repositories. This declarative approach means that the desired state of the application is explicitly defined, rather than the steps needed to achieve that state. This makes configurations easier to understand, review, and audit.

- **Automated Synchronization**: ArgoCD continuously monitors the Git repositories for changes and automatically applies them to the Kubernetes cluster. When a change is detected, ArgoCD compares the current state of the cluster with the desired state defined in Git and makes the necessary changes to align them. This automation reduces manual deployment steps and potential for human error.

- **Drift Detection**: The system continuously compares the actual state of the deployed applications with the desired state defined in Git. If any unauthorized changes are made directly to the cluster (configuration drift), ArgoCD detects these discrepancies and can alert administrators or automatically remediate them.

- **Self-Healing**: ArgoCD's self-healing capabilities automatically restore the desired state when manual changes occur or when resources are accidentally deleted. This ensures that the system remains in the desired state even in the face of unexpected changes or failures.

- **Rollback Capabilities**: Since all configurations are version-controlled in Git, rolling back to a previous known-good state is as simple as reverting to a previous commit and letting ArgoCD synchronize the change.

- **Audit Trail**: All changes to the infrastructure and applications are tracked in Git, providing a comprehensive audit trail of who made what changes and when.

- **Multi-Environment Support**: The same GitOps approach can be used across different environments (development, staging, production) with environment-specific configurations, ensuring consistency in the deployment process.

The ArgoCD implementation includes several key components:

1. **Project Definition**: The `thesis` project in ArgoCD organizes applications and defines access controls:

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: AppProject
   metadata:
     name: thesis
     namespace: argocd
   spec:
     description: Thesis Project for Frontend and Backend Applications
     sourceRepos:
       - https://github.com/tpSpace/thesis-fe.git
       - https://github.com/tpSpace/thesis-be.git
       - https://github.com/tpSpace/infra.git
   ```

2. **Application Definitions**: Separate applications for frontend and backend services, each pointing to their respective paths in the infrastructure repository.

3. **Repository Secrets**: Secure access to Git repositories through SSH keys stored as Kubernetes secrets.

4. **Synchronization Policies**: Automated policies that control how and when changes are applied, including options for pruning resources, self-healing, and retry strategies.

The GitOps workflow established with ArgoCD ensures that the deployment process is consistent, auditable, and automated, significantly reducing the operational burden and increasing the reliability of the system.

### 3.2.3 Repository Structure

The system follows a clear repository separation pattern that embodies modern DevOps practices and the separation of concerns principle. This multi-repository approach provides several advantages for development workflow, security, and maintainability:

1. **Infrastructure Repository (`infra`)**:
   - Contains all Terraform configurations for provisioning cloud resources
   - Houses Kubernetes manifests for all application components
   - Includes ArgoCD configuration files for GitOps deployment
   - Serves as the single source of truth for infrastructure state
   - Repository structure:

     ```bash
     infra/
     ├── argocd-configs/       # ArgoCD application definitions
     ├── be/                   # Backend Kubernetes manifests
     ├── fe/                   # Frontend Kubernetes manifests
     ├── main.tf               # Main Terraform configuration
     ├── variables.tf          # Terraform variable definitions
     ├── terraform.tfvars      # Terraform variable values
     ├── statefulset-db.yaml   # Database configuration
     ├── configmap.yaml        # Application configuration
     ├── secret.yaml           # Sensitive data configuration
     └── ingress.yaml          # External access configuration
     ```

2. **Frontend Repository (`thesis-fe`)**:
   - Contains the Next.js application code for the user interface
   - Includes its own CI/CD workflow for building and testing
   - Maintains frontend-specific documentation
   - Follows a typical Next.js project structure with pages, components, and API routes
   - Contains Dockerfile for containerization

3. **Backend Repository (`thesis-be`)**:
   - Houses the GraphQL API and bug localization service implementation
   - Includes database schema definitions and migrations
   - Contains service-specific tests and documentation
   - Implements the core bug localization algorithms
   - Includes Dockerfile for containerization

This separation enables:

- **Independent Development Cycles**: Frontend and backend teams can work at their own pace without tight coupling
- **Specialized Access Control**: Different teams can have different levels of access to each repository
- **Focused Code Reviews**: Pull requests are more focused and easier to review
- **Targeted CI/CD Pipelines**: Each repository has its own CI/CD workflow optimized for its specific needs
- **Clear Ownership**: Each team has clear ownership of their respective components
- **Reduced Merge Conflicts**: Fewer developers working in the same repository reduces the likelihood of conflicts
- **Simplified Dependency Management**: Each component manages its own dependencies

The workflow between repositories is coordinated through the GitOps process:

1. Developers commit code to the application repositories (`thesis-fe` or `thesis-be`)
2. CI pipelines build, test, and publish container images with appropriate tags
3. The infrastructure repository (`infra`) is updated with new image tags
4. ArgoCD detects the changes and deploys the updated applications

This multi-repository approach, while adding some complexity in coordination, provides significant benefits in terms of separation of concerns, security, and maintainability. It allows each component to evolve independently while maintaining a consistent deployment process through the GitOps workflow.

## 3.3 Containerization Strategy

### 3.3.1 Container Design Principles

The containerization strategy follows industry best practices and principles that ensure efficient, secure, and maintainable container deployments. These principles are applied consistently across all services:

- **Single Responsibility**: Each container has a specific, limited purpose following the Unix philosophy of "do one thing and do it well." This approach:
  - Simplifies container lifecycle management
  - Improves security by reducing the attack surface
  - Enhances scalability by allowing independent scaling of components
  - Facilitates easier updates and maintenance
  - Examples include separating the database, backend API, and frontend into distinct containers

- **Immutability**: Containers are treated as immutable artifacts, rebuilt for any change rather than modified in place:
  - Ensures consistency across environments
  - Eliminates configuration drift
  - Provides reliable rollback capabilities
  - Simplifies debugging by guaranteeing the exact same code is running everywhere
  - Implemented through versioned container images and declarative deployments

- **Resource Efficiency**: Containers are optimized with appropriate resource limits and requests:

  ```yaml
  resources:
    limits:
      cpu: "500m"
      memory: "512Mi"
    requests:
      cpu: "200m"
      memory: "256Mi"
  ```

  This approach:
  - Prevents resource starvation in the cluster
  - Enables effective scheduling and bin-packing
  - Provides predictable performance characteristics
  - Optimizes cloud resource utilization and cost
  - Allows for accurate capacity planning

- **Security**: Containers run with minimal required privileges following the principle of least privilege:
  - Non-root users are used whenever possible
  - Read-only file systems are employed where appropriate
  - Only necessary ports are exposed
  - Secrets are managed through Kubernetes Secrets rather than baked into images
  - Container images are regularly scanned for vulnerabilities

The containerization process follows a standardized workflow:

1. **Base Image Selection**: Using official, minimal, and regularly updated base images
2. **Dependency Management**: Clear specification of dependencies with version pinning
3. **Multi-stage Builds**: Separating build environments from runtime environments
4. **Layer Optimization**: Organizing Dockerfile instructions to maximize layer caching
5. **Health Checks**: Implementing appropriate health check mechanisms
6. **Configuration**: Externalizing configuration through environment variables

### 3.3.2 Container Registry and CI/CD Integration

Container images are stored in GitHub Container Registry (GHCR), which provides a tightly integrated solution for the GitHub-based development workflow. The container registry strategy includes:

- **Versioned Tagging Strategy**:
  - Semantic versioning (e.g., `v1.0.0`, `v1.0.1`) for release images
  - Git commit SHA tags (e.g., `git-7d3f54c`) for precise traceability
  - Branch-based tags (e.g., `main-latest`) for development workflows
  - Latest tag for development environments, facilitating rapid iteration

- **Access Control and Security**:
  - Integration with GitHub's permission model
  - Repository-level access control
  - Kubernetes secrets for secure registry authentication:

    ```yaml
    apiVersion: v1
    kind: Secret
    metadata:
      name: ghcr-secret
      namespace: my-thesis
    type: kubernetes.io/dockerconfigjson
    data:
      .dockerconfigjson: <encoded_credentials>
    ```

  - Vulnerability scanning of container images

- **CI/CD Integration**:
  - Automated image building on code commits
  - Parallel building of images for different architectures
  - Automated testing before image publishing
  - Integration with GitHub Actions workflows:

    ```yaml
    # Example GitHub Actions workflow for container building
    name: Build and Push Container
    on:
      push:
        branches: [main]
    jobs:
      build:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v3
          - name: Build and push
            uses: docker/build-push-action@v4
            with:
              context: .
              push: true
              tags: ghcr.io/tpspace/thesis-be:latest
    ```

- **Image Lifecycle Management**:
  - Automated cleanup of unused images
  - Retention policies for historical images
  - Image promotion workflows from development to production

This comprehensive containerization strategy ensures that the application components are packaged in a consistent, secure, and efficient manner, facilitating reliable deployments and simplifying operations throughout the application lifecycle.

## 3.4 Kubernetes Deployment Strategy

### 3.4.1 Resource Organization

Kubernetes resources are organized following best practices:

- **Namespaces**: Separate `my-thesis` namespace for application components and `argocd` namespace for GitOps tooling
- **Labels and Selectors**: Consistent labeling for service discovery
- **ConfigMaps and Secrets**: Externalized configuration to separate code from environment-specific settings

### 3.4.2 Deployment Patterns

The system implements several deployment patterns:

1. **StatefulSet for Database**:

  ```yaml
  apiVersion: apps/v1
  kind: StatefulSet
  metadata:
    name: postgres
    namespace: my-thesis
  spec:
    serviceName: postgres-headless
    replicas: 1
    # Configuration for data persistence and health checks...
  ```

2. **Deployments for Stateless Services**:

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: backend
    namespace: my-thesis
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: backend
    # Configuration for container image, environment variables, and health probes...
  ```

3. **Services for Internal Communication**:

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: backend
    namespace: my-thesis
  spec:
    selector:
      app: backend
    ports:
    - port: 4000
  # Additional configuration...
  ```

4. **Ingress for External Access**:

  ```yaml
  apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: public-ingress
    namespace: my-thesis
  spec:
    rules:
      - http:
          paths:
            - path: /api(/|$)(.*)
              pathType: Prefix
              backend:
                service:
                  name: backend
                  port:
                    number: 4000
            # Additional routing rules...
  ```

5. **Deployment for RabbitMQ**:

  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: rabbitmq
    namespace: my-thesis
  spec:
    replicas: 1
    selector:
      matchLabels:
        app: rabbitmq
    template:
      metadata:
        labels:
          app: rabbitmq
      spec:
        containers:
        - name: rabbitmq
          image: rabbitmq:3-management
          ports:
          - containerPort: 5672
          - containerPort: 15672
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
  ```

6. **Service for RabbitMQ**:

  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: rabbitmq
    namespace: my-thesis
  spec:
    selector:
      app: rabbitmq
    ports:
    - port: 5672
      targetPort: 5672
    - port: 15672
      targetPort: 15672
  ```

### 3.4.3 High Availability and Scaling

High availability and scaling are achieved through:

- **Horizontal Pod Autoscaling**: Backend services can scale based on CPU/memory utilization
- **Node Autoscaling**: GKE node pool configured to scale from 2 to 5 nodes based on workload
- **Health Probes**: Both liveness and readiness probes ensure service health:

  ```yaml
  livenessProbe:
    httpGet:
      path: /health
      port: 4000
    initialDelaySeconds: 30
    periodSeconds: 20
  ```

- **Resource Allocation**: Precise resource requests and limits for predictable performance

## 3.5 Database Strategy

### 3.5.1 Database Selection and Configuration

PostgreSQL was selected as the database solution for several reasons:

- ACID compliance for data integrity in student code submissions
- Rich query capabilities for complex bug localization algorithms
- Strong performance characteristics and Kubernetes integration
- Robust community support and documentation

The PostgreSQL database is deployed as a StatefulSet with:

```yaml
volumeClaimTemplates:
  - metadata:
      name: postgres-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: standard
      resources:
        requests:
          storage: 10Gi
```

### 3.5.2 Data Persistence and Security

Data persistence is ensured through:

- Persistent Volume Claims managed by StatefulSets
- Volume claim templates for automatic provisioning
- Environment variables stored in Kubernetes Secrets:

  ```yaml
  env:
    - name: POSTGRES_DB
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: db_name
    # Additional environment variables...
  ```

## 3.6 Continuous Integration and Deployment

### 3.6.1 CI/CD Pipeline Architecture

The CI/CD pipeline integrates multiple components:

1. **Source Code Management**: GitHub repositories for application and infrastructure code
2. **Automated Testing**: Unit and integration tests run on each commit
3. **Container Building**: Automated container builds push to GitHub Container Registry
4. **ArgoCD Deployment**: Automated synchronization from Git to Kubernetes

### 3.6.2 GitOps Workflow

The GitOps workflow follows a structured process:

1. Developers commit code changes to application repositories
2. CI pipeline builds, tests, and publishes container images
3. Infrastructure repository is updated with new image versions
4. ArgoCD detects changes and applies them to the Kubernetes cluster
5. ArgoCD continuously monitors for drift and ensures desired state

This approach enforces separation of concerns while maintaining automation:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: thesis
  namespace: argocd
spec:
  description: Thesis Project for Frontend and Backend Applications
  sourceRepos:
    - https://github.com/tpSpace/thesis-fe.git
    - https://github.com/tpSpace/thesis-be.git
    - https://github.com/tpSpace/infra.git
  # Additional configuration...
```

## 3.7 Monitoring and Observability

### 3.7.1 Health Monitoring

Application health is monitored through:

- **Kubernetes Probes**: Both liveness and readiness probes ensure service availability
- **Health Endpoints**: Dedicated health check endpoints in the backend service
- **ArgoCD Status Monitoring**: Continuous state verification through ArgoCD

### 3.7.2 Logging and Debugging

The system implements comprehensive logging:

- Container standard output and error streams
- Structured logging formats for machine readability
- Kubernetes log aggregation for centralized access
