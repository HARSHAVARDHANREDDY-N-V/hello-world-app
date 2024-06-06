# Hello World Node.js App on AWS ECS/Fargate with Terraform and GitHub Actions

This project demonstrates deploying a simple "Hello World" Node.js application on AWS ECS/Fargate using Terraform for infrastructure as code and GitHub Actions for continuous deployment.

## Prerequisites

Before you start, make sure you have the following installed:

1. [AWS CLI](https://aws.amazon.com/cli/)
2. [Terraform](https://www.terraform.io/)
3. [Docker](https://www.docker.com/)
4. [Git](https://git-scm.com/)
5. A GitHub account

## Project Structure

```plaintext
hello-world-app/
├── .github/
│   └── workflows/
│       └── deploy.yml
├── terraform/
│   ├── main.tf
│   ├── outputs.tf
│   ├── variables.tf
│   └── ecs_task_definition.json
├── Dockerfile
├── package.json
├── package-lock.json
└── README.md
```

## Step-by-Step Guide

### 1. Clone the Repository

```sh
git clone https://github.com/your-github-username/hello-world-app.git
cd hello-world-app
```

### 2. Set Up Terraform

1. **Navigate to the Terraform directory:**

    ```sh
    cd terraform
    ```

2. **Initialize Terraform:**

    ```sh
    terraform init
    ```

3. **Create a `main.tf` file with the following content:**

    ```hcl
    provider "aws" {
      region = "us-east-1"
    }

    resource "aws_vpc" "main" {
      cidr_block = "10.0.0.0/16"
    }

    resource "aws_subnet" "subnet" {
      vpc_id     = aws_vpc.main.id
      cidr_block = "10.0.1.0/24"
    }

    resource "aws_security_group" "main" {
      vpc_id = aws_vpc.main.id

      ingress {
        from_port   = 80
        to_port     = 80
        protocol    = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
      }

      egress {
        from_port   = 0
        to_port     = 0
        protocol    = "-1"
        cidr_blocks = ["0.0.0.0/0"]
      }
    }

    resource "aws_ecs_cluster" "main" {
      name = "main"
    }

    resource "aws_ecs_task_definition" "main" {
      family                   = "hello-world"
      network_mode             = "awsvpc"
      requires_compatibilities = ["FARGATE"]
      cpu                      = "256"
      memory                   = "512"

      container_definitions = file("${path.module}/ecs_task_definition.json")
      execution_role_arn    = aws_iam_role.ecs_task_execution.arn
    }

    resource "aws_iam_role" "ecs_task_execution" {
      name = "ecsTaskExecutionRole"

      assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [{
          Action    = "sts:AssumeRole",
          Effect    = "Allow",
          Principal = {
            Service = "ecs-tasks.amazonaws.com"
          }
        }]
      })

      managed_policy_arns = [
        "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
      ]
    }

    resource "aws_ecs_service" "main" {
      name            = "hello-world-service"
      cluster         = aws_ecs_cluster.main.id
      task_definition = aws_ecs_task_definition.main.arn
      desired_count   = 1

      network_configuration {
        subnets          = [aws_subnet.subnet.id]
        security_groups  = [aws_security_group.main.id]
        assign_public_ip = true
      }
    }
    ```

4. **Create an `ecs_task_definition.json` file with the following content:**

    ```json
    [
      {
        "name": "hello-world",
        "image": "your-dockerhub-username/hello-world-app:latest",
        "essential": true,
        "portMappings": [
          {
            "containerPort": 3000,
            "hostPort": 3000
          }
        ]
      }
    ]
    ```

5. **Apply Terraform configuration:**

    ```sh
    terraform apply
    ```

    **Note:** Make sure to review the plan and type `yes` to confirm the apply.

### 3. Prepare the Node.js Application

1. **Create a simple Node.js application:**

    ```javascript
    // app.js
    const express = require('express');
    const app = express();

    app.get('/', (req, res) => {
      res.send('Hello, World!');
    });

    const port = process.env.PORT || 3000;
    app.listen(port, () => {
      console.log(`Server is running on port ${port}`);
    });
    ```

2. **Create a `package.json` file:**

    ```json
    {
      "name": "hello-world-app",
      "version": "1.0.0",
      "description": "Hello World Node.js App",
      "main": "app.js",
      "scripts": {
        "start": "node app.js"
      },
      "dependencies": {
        "express": "^4.17.1"
      }
    }
    ```

3. **Install dependencies:**

    ```sh
    npm install
    ```

4. **Create a Dockerfile:**

    ```dockerfile
    # Use an official Node runtime as a parent image
    FROM node:14

    # Set the working directory
    WORKDIR /usr/src/app

    # Copy the package.json and package-lock.json
    COPY package*.json ./

    # Install dependencies
    RUN npm install

    # Copy the rest of the application code
    COPY . .

    # Expose the port the app runs on
    EXPOSE 3000

    # Command to run the application
    CMD ["npm", "start"]
    ```

### 4. Set Up GitHub Actions for Continuous Deployment

1. **Create GitHub Actions workflow file:**

    ```plaintext
    .github/
    └── workflows/
        └── deploy.yml
    ```

2. **Add the following content to `deploy.yml`:**

    ```yaml
    name: Deploy to ECS

    on:
      push:
        branches:
          - main

    jobs:
      build:
        runs-on: ubuntu-latest

        steps:
          - name: Checkout code
            uses: actions/checkout@v2

          - name: Set up Docker Buildx
            uses: docker/setup-buildx-action@v1

          - name: Login to DockerHub
            uses: docker/login-action@v1
            with:
              username: ${{ secrets.DOCKER_USERNAME }}
              password: ${{ secrets.DOCKER_PASSWORD }}

          - name: Build and push Docker image
            uses: docker/build-push-action@v2
            with:
              context: .
              push: true
              tags: your-dockerhub-username/hello-world-app:latest

          - name: Deploy to ECS
            uses: aws-actions/amazon-ecs-deploy-task-definition@v1
            with:
              task-definition: ecs_task_definition.json
              service: hello-world-service
              cluster: arn:aws:ecs:us-east-1:253182973100:cluster/main
              wait-for-service-stability: true
            env:
              AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
              AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
              AWS_REGION: us-east-1
    ```

3. **Add secrets to GitHub repository:**

    - Go to your repository on GitHub.
    - Click on `Settings`.
    - Navigate to `Secrets and variables > Actions`.
    - Add the following secrets:
      - `DOCKER_USERNAME`: Your DockerHub username.
      - `DOCKER_PASSWORD`: Your DockerHub password.
      - `AWS_ACCESS_KEY_ID`: Your AWS access key ID.
      - `AWS_SECRET_ACCESS_KEY`: Your AWS secret access key.

### 5. Deploy Your Application

- **Push your code to GitHub:**

    ```sh
    git add .
    git commit -m "Initial commit"
    git push origin main
    ```

- **GitHub Actions will automatically build and deploy your application to ECS.**

### 6. Monitor Your Application

- Use AWS CloudWatch to monitor the performance and health of your ECS service and tasks.
- Monitor CPU and memory utilization, as well as any logs generated by your application.

### 7. Implement Continuous Deployment (Optional)

- Configure a CI/CD pipeline using GitHub Actions (already set up in the `deploy.yml`).
- Automate the process of building, testing, and deploying your application whenever changes are pushed to your repository.

### 8. Test and Scale Your Application

- Test your application to ensure it is functioning as expected in the ECS environment.
- Use AWS ECS Auto Scaling to automatically scale your application based on defined metrics such as CPU utilization or request count.

### 9. Regular Maintenance and Updates

- Perform regular maintenance tasks such as patching, updating dependencies, and optimizing resource utilization.
- Stay informed about AWS ECS/Fargate best practices, new features, and updates to ensure your application remains secure and optimized.

### Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/Welcome.html)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Documentation](https://docs.docker.com/)

---

Feel free to reach out if you have any questions or need further assistance.

Happy coding!
```

This `README.md` file provides a comprehensive guide for setting up, deploying, and maintaining the "Hello World" Node.js application on AWS ECS/Fargate using Terraform and GitHub Actions.

