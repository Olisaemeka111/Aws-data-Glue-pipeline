# AWS Data Glue ETL Pipeline - Complete Cost Analysis

## 📊 **DEPLOYMENT COST BREAKDOWN**

**Analysis Date:** December 13, 2025  
**Region:** us-east-1  
**Environment:** dev  
**Total Resources:** 102 deployed resources  

---

## 💰 **MONTHLY COST ESTIMATE BY SERVICE**

### **🌐 VPC & Networking - $99.45/month**

| Resource | Quantity | Unit Cost | Monthly Cost | Notes |
|----------|----------|-----------|--------------|-------|
| **NAT Gateways** | 3 | $32.40/mo | **$97.20** | Highest cost component |
| **Elastic IPs** | 3 | $0.00 | $0.00 | Free when attached |
| **VPC Endpoints** | 5 | $0.45/mo | $2.25 | Interface endpoints |
| **VPC/Subnets/Routes** | - | $0.00 | $0.00 | Free |

### **🗄️ Storage (S3) - $5.10/month**

| Bucket | Est. Size | Storage Cost | Operations | Monthly Cost |
|--------|-----------|--------------|------------|--------------|
| **Raw Data** | 10 GB | $0.23 | PUT/GET | $0.50 |
| **Processed Data** | 8 GB | $0.18 | PUT/GET | $0.40 |
| **Curated Data** | 5 GB | $0.12 | PUT/GET | $0.30 |
| **Scripts** | 0.1 GB | $0.002 | PUT/GET | $0.10 |
| **Temp** | 2 GB | $0.05 | PUT/GET | $0.20 |
| **Lifecycle/Versioning** | - | - | Rules | $3.60 |
| **Total S3** | 25.1 GB | - | - | **$5.10** |

### **🔄 AWS Glue - $45.50/month**

| Component | Usage | Unit Cost | Monthly Cost | Notes |
|-----------|-------|-----------|--------------|-------|
| **Glue Catalog** | 1 database | $1.00/mo | $1.00 | First 1M requests free |
| **Data Crawlers** | 3 crawlers | $2.00/crawler | $6.00 | Daily runs |
| **ETL Jobs (dev)** | 10 runs/mo | $3.85/run | $38.50 | G.1X, 2 workers, 30min avg |
| **Workflow/Triggers** | - | $0.00 | $0.00 | No additional cost |

### **📊 DynamoDB - $2.45/month**

| Table | Type | Est. Usage | Monthly Cost | Notes |
|-------|------|------------|--------------|-------|
| **job-bookmarks** | On-demand | 100 reads/writes | $0.60 | Job state tracking |
| **metadata** | On-demand | 200 reads/writes | $1.20 | Metadata storage |
| **job_state** | On-demand | 50 reads/writes | $0.30 | Glue job states |
| **scan_results** | On-demand | 150 reads/writes | $0.35 | Security scans |
| **Total DynamoDB** | - | - | **$2.45** | Includes storage |

### **⚡ Lambda Functions - $0.85/month**

| Function | Invocations | Duration | Memory | Monthly Cost |
|----------|-------------|----------|--------|--------------|
| **data-trigger** | 500/mo | 10s avg | 128 MB | $0.45 |
| **monitoring** | 1000/mo | 5s avg | 128 MB | $0.40 |
| **Total Lambda** | - | - | - | **$0.85** |

### **📈 CloudWatch - $18.60/month**

| Component | Quantity | Unit Cost | Monthly Cost | Notes |
|-----------|----------|-----------|--------------|-------|
| **Log Groups** | 8 groups | $0.50/GB | $4.00 | 1GB ingestion est. |
| **Metric Alarms** | 12 alarms | $0.10/alarm | $1.20 | Failure/duration monitoring |
| **Custom Metrics** | 50 metrics | $0.30/metric | $15.00 | Glue job metrics |
| **Dashboards** | 2 dashboards | $3.00/dash | $6.00 | Security + Glue dashboards |
| **Event Rules** | 5 rules | $1.00/million | $0.40 | EventBridge rules |
| **Total CloudWatch** | - | - | **$18.60** | High due to Glue metrics |

### **🔐 Security Services - $7.25/month**

| Service | Component | Monthly Cost | Notes |
|---------|-----------|--------------|-------|
| **KMS Keys** | 6 keys | $6.00 | $1.00/key/month |
| **Secrets Manager** | 1 secret | $0.40 | $0.40/secret/month |
| **Security Hub** | Standards | $0.30 | AWS Foundational |
| **IAM** | Roles/Policies | $0.00 | Free |
| **Total Security** | - | **$7.25** | |

### **📢 Notification Services - $0.75/month**

| Service | Usage | Monthly Cost | Notes |
|---------|-------|--------------|-------|
| **SNS Topics** | 2 topics | $0.50 | 1000 notifications |
| **Email Notifications** | 100 emails | $0.25 | Job status alerts |
| **Total SNS** | - | **$0.75** | |

---

## 💸 **TOTAL MONTHLY COST BREAKDOWN**

| Service Category | Monthly Cost | Percentage | Cost Type |
|------------------|--------------|------------|-----------|
| **VPC & Networking** | $99.45 | 55.8% | 🔴 High (NAT Gateways) |
| **CloudWatch** | $18.60 | 10.4% | 🟡 Medium (Metrics) |
| **AWS Glue** | $45.50 | 25.5% | 🟡 Medium (Variable) |
| **Security** | $7.25 | 4.1% | 🟢 Low |
| **S3 Storage** | $5.10 | 2.9% | 🟢 Low |
| **DynamoDB** | $2.45 | 1.4% | 🟢 Low |
| **Lambda** | $0.85 | 0.5% | 🟢 Low |
| **SNS** | $0.75 | 0.4% | 🟢 Low |

## 🎯 **TOTAL ESTIMATED MONTHLY COST: $179.95**

---

## 📈 **COST SCALING FACTORS**

### **Variable Costs (Usage-Based):**
- **Glue Jobs**: $3.85 per job run (G.1X, 2 workers, 30 min)
- **S3 Storage**: $0.023/GB/month
- **DynamoDB**: $0.25 per million read/write units
- **Lambda**: $0.20 per million requests
- **CloudWatch Logs**: $0.50/GB ingested

### **Fixed Costs (Always Running):**
- **NAT Gateways**: $97.20/month (biggest fixed cost)
- **KMS Keys**: $6.00/month
- **VPC Endpoints**: $2.25/month

---

## 🔄 **COST OPTIMIZATION RECOMMENDATIONS**

### **High Impact (Potential 50% savings):**

1. **Remove NAT Gateways** → **Save $97.20/month**
   - Use VPC Endpoints instead of NAT for AWS services
   - Current setup: 3 NAT Gateways ($32.40 each)
   - Alternative: Additional VPC Endpoints ($2.70)

2. **Optimize Glue Jobs** → **Save $20-30/month**
   - Use G.1X workers only when needed
   - Implement job scheduling to reduce runs
   - Use Glue Studio for cost monitoring

### **Medium Impact (Potential 20% savings):**

3. **CloudWatch Optimization** → **Save $8-12/month**
   - Reduce custom metrics collection
   - Optimize log retention periods
   - Use log aggregation

4. **S3 Lifecycle Policies** → **Save $2-4/month**
   - Move old data to IA/Glacier
   - Optimize versioning policies

### **Low Impact (Potential 5% savings):**

5. **DynamoDB Optimization** → **Save $1-2/month**
   - Review table capacity settings
   - Optimize TTL settings

---

## 📊 **COST COMPARISON BY ENVIRONMENT**

| Environment | Est. Monthly Cost | Usage Pattern | Notes |
|-------------|-------------------|---------------|--------|
| **Development** | $179.95 | Current deployment | Full infrastructure |
| **Production** | $450-650 | Higher usage | 3x Glue runs, larger data |
| **Staging** | $220-280 | Medium usage | Similar infra, more testing |

---

## 🎯 **ANNUAL COST PROJECTION**

| Scenario | Monthly | Annual | Notes |
|----------|---------|--------|--------|
| **Current (Dev)** | $179.95 | **$2,159.40** | As deployed |
| **Optimized (Dev)** | $85.50 | **$1,026.00** | With NAT removal |
| **Production** | $525.00 | **$6,300.00** | Full load |

---

## ⚠️ **COST ALERTS RECOMMENDATIONS**

1. **Set Budget Alert**: $200/month for dev environment
2. **Monitor NAT Gateway usage**: >80% of total cost
3. **Track Glue job runs**: Cost scales with frequency
4. **S3 storage growth**: Monitor data retention policies

---

## 📋 **OPTIMIZATION SUMMARY**

**Current Monthly Cost**: $179.95  
**Optimized Monthly Cost**: $85.50  
**Potential Savings**: $94.45/month (52.5%)  
**Annual Savings**: $1,133.40  

**Key Action**: Remove NAT Gateways and use VPC Endpoints for 50%+ cost reduction.

---

*Last Updated: December 13, 2025*  
*Pricing based on AWS us-east-1 region current rates* 