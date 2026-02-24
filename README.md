# Azure-cost-optimizer
Automates Azure cost analysis using PowerShell + Resource Graph Detects orphaned resources, idle VMs, and unused networking Generates HTML cost reports with estimated savings

## 🔍 Project Type
Cloud Cost Optimization • Azure Automation • Infrastructure Engineering

## 🚀 Features
- Automated Azure cost analysis using PowerShell and Azure Resource Graph
- Detects orphaned managed disks and unused storage resources
- Identifies unattached Public IPs and unused network interfaces
- Finds stopped or deallocated VMs still incurring disk costs
- Detects old snapshots based on configurable age threshold
- Generates interactive HTML reports with estimated monthly savings
- Works across subscriptions and resource groups
- Designed for automation and scheduled execution

## 🧱 Architecture
This project uses Azure PowerShell and Azure Resource Graph to scan cloud
resources and identify cost optimization opportunities.

Workflow:
1. Authenticate to Azure using Az PowerShell modules
2. Query resources across subscription
3. Analyze utilization patterns and attachment status
4. Estimate monthly storage and infrastructure costs
5. Generate HTML dashboard report

Components:
- PowerShell Automation Script
- Azure Resource Graph Queries
- HTML Report Generator
- Cost Estimation Engine

## 📊 Sample Output
The tool generates an HTML dashboard that summarizes:

- Total potential monthly savings
- Unused resources grouped by type
- Estimated cost impact
- Resource metadata and location

Reports can be used by engineers or management teams to
identify immediate cost optimization opportunities.

## 💰 Cost Savings Example
Example findings from learning environment:

| Resource Type | Count | Estimated Monthly Savings |
|---|---|---|
| Orphaned Disks | 4 | $20.48 |
| Stopped VMs | 1 | $5.08 |


Estimated Total Monthly Savings: $25.56

## ⚙️ Tech Stack
- Azure PowerShell (Az Modules)
- PowerShell Scripting
- Azure Resource Graph
- Azure Compute / Network APIs
- Infrastructure Cost Analysis
- HTML Report Generation
- Azure Automation Ready

## 📸 Screenshots
### HTML Cost Optimization Report
![HTML Report](screenshots/report.png)

### Azure Deployment Example
![Azure Resources](screenshots/resources.png)

### Script Execution Output
![PowerShell Output](screenshots/script-run.png)

### Architecture Overview
![Architecture Diagram](screenshots/architecture.png)

## 🧠 Lessons Learned
- Identifying hidden Azure costs requires cross-resource analysis
- Stopped VMs still generate storage charges
- Orphaned networking resources can accumulate unnoticed
- Infrastructure automation improves visibility into cloud spend
- HTML reporting helps communicate technical findings to stakeholders
- Designing scripts for automation requires careful error handling


