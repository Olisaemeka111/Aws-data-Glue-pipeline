# 💰 EC2 Resources Cost Analysis

**Region:** US-East-1 (N. Virginia)  
**Analysis Date:** December 2025  
**Resources from AWS Glue ETL Pipeline**  

---

## 🚨 **COST IMPLICATIONS SUMMARY**

Based on your EC2 dashboard, here are the cost-generating resources:

### **💸 ACTIVE COST COMPONENTS**

| Resource Type | Count | Monthly Cost Est. | Annual Cost Est. | Notes |
|---------------|-------|------------------|------------------|-------|
| **🔴 EC2 Instance** | 1 | $8-50+ | $96-600+ | **If running 24/7** |
| **🟡 EBS Volume** | 1 | $0.80-8+ | $10-100+ | Depends on size/type |
| **🟡 EBS Snapshots** | 2 | $0.50-5+ | $6-60+ | Depends on size |
| **✅ Security Groups** | 6 | $0 | $0 | Free |
| **✅ Key Pairs** | 3 | $0 | $0 | Free |

**🔺 TOTAL ESTIMATED COST: $9.30 - $63+ per month**

---

## 📊 **DETAILED COST BREAKDOWN**

### **🔴 HIGH PRIORITY - EC2 Instance (1 instance)**

**Cost Impact: MODERATE to HIGH**
```yaml
Instance Scenarios:
├── t3.micro (stopped): $0/month ✅
├── t3.micro (running): ~$8.50/month
├── t3.small (running): ~$17/month  
├── t3.medium (running): ~$34/month
├── m5.large (running): ~$70/month
└── If left running accidentally: Up to $600+/year

Cost Factors:
├── Instance type (t3.micro vs larger)
├── Running time (hours per month)
├── Data transfer costs
└── Elastic IP if attached
```

**⚠️ CRITICAL CHECK NEEDED:**
```bash
# Check if instance is running (costing money)
aws ec2 describe-instances --region us-east-1 \
  --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name]'

# If running unnecessarily:
aws ec2 stop-instances --instance-ids <instance-id>
```

### **🟡 MEDIUM PRIORITY - EBS Volume (1 volume)**

**Cost Impact: LOW to MODERATE**
```yaml
Volume Cost Scenarios:
├── gp3 8GB: ~$0.80/month ✅ Low cost
├── gp3 20GB: ~$2.00/month
├── gp3 100GB: ~$10.00/month
├── io1/io2 volumes: Much higher costs
└── Unused attached volumes: Waste money

Monthly Cost Formula:
├── GP3: $0.08 per GB-month
├── GP2: $0.10 per GB-month  
├── IO1: $0.125 per GB-month + IOPS costs
└── Provisioned IOPS: Additional $0.065 per IOPS-month
```

### **🟡 MEDIUM PRIORITY - EBS Snapshots (2 snapshots)**

**Cost Impact: LOW**
```yaml
Snapshot Costs:
├── Small snapshots (1-5GB each): ~$0.25-1.25/month
├── Medium snapshots (10-20GB each): ~$2.50-5.00/month
├── Large snapshots (100GB+ each): $12.50+/month
└── Incremental storage pricing: $0.05 per GB-month

Optimization:
├── Delete old/unnecessary snapshots
├── Automate snapshot lifecycle management
├── Use snapshot scheduling for backups only
└── Monitor snapshot growth over time
```

---

## 🎯 **COST OPTIMIZATION RECOMMENDATIONS**

### **🚨 IMMEDIATE ACTIONS (Do Today)**

1. **Check Instance State**
   ```bash
   # Verify if EC2 instance is needed
   aws ec2 describe-instances --region us-east-1
   
   # Stop if not needed
   aws ec2 stop-instances --instance-ids <instance-id>
   
   # Terminate if never needed
   aws ec2 terminate-instances --instance-ids <instance-id>
   ```

2. **Review EBS Volumes**
   ```bash
   # Check volume usage and attachment
   aws ec2 describe-volumes --region us-east-1
   
   # Delete unattached volumes
   aws ec2 delete-volume --volume-id <volume-id>
   ```

3. **Clean Up Snapshots**
   ```bash
   # List all snapshots
   aws ec2 describe-snapshots --owner-ids self --region us-east-1
   
   # Delete unnecessary snapshots
   aws ec2 delete-snapshot --snapshot-id <snapshot-id>
   ```

### **⚡ QUICK WINS (This Week)**

**A. Set Up Instance Scheduler**
```yaml
Potential Savings: 60-80% on instance costs
Implementation:
├── Use AWS Instance Scheduler
├── Stop instances during non-business hours
├── Weekend shutdown for dev/test instances
└── Save $200-400/year per instance
```

**B. Implement Volume Monitoring**
```yaml
Monitoring Setup:
├── CloudWatch alarms for unused volumes
├── Automated cleanup of unattached volumes
├── Lifecycle policies for snapshots
└── Regular cost review and optimization
```

**C. Right-Size Resources**
```yaml
Instance Optimization:
├── Monitor CPU utilization (should be >20%)
├── Downgrade oversized instances
├── Use burstable instances (t3) for variable workloads
└── Consider Spot instances for non-critical work
```

---

## 📈 **COST MONITORING SETUP**

### **🔍 Cost Tracking Commands**

```bash
# Get current month EC2 costs
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --group-by Type=DIMENSION,Key=SERVICE \
  --filter file://ec2-filter.json

# Check instance usage
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<instance-id> \
  --start-time $(date -d '7 days ago' -u +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 3600 \
  --statistics Average
```

### **📊 Cost Alerts Setup**

```bash
# Create EC2 cost budget alert
aws budgets create-budget \
  --account-id $(aws sts get-caller-identity --query Account --output text) \
  --budget '{
    "BudgetName": "EC2-Monthly-Budget",
    "BudgetLimit": {"Amount": "25", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST",
    "CostFilters": {
      "Service": ["Amazon Elastic Compute Cloud - Compute"]
    }
  }'
```

---

## 🚦 **RESOURCE RELATIONSHIP TO GLUE PIPELINE**

### **🤔 Why These EC2 Resources Exist**

Based on your Glue ETL pipeline, these EC2 resources might be:

1. **EC2 Instance (1)**
   ```yaml
   Possible Reasons:
   ├── Development/testing environment
   ├── Jupyter notebook server for data analysis
   ├── Bastion host for secure access
   ├── Custom application server
   └── ⚠️ Accidentally created or forgotten
   
   Cost Impact: $8-50+/month if running
   Action: Verify necessity and stop if not needed
   ```

2. **EBS Volume (1)**
   ```yaml
   Likely Purpose:
   ├── Root volume for EC2 instance
   ├── Additional storage for data processing
   ├── Backup storage for important files
   └── Development environment storage
   
   Cost Impact: $0.80-10+/month
   Action: Right-size and clean up unused volumes
   ```

3. **Snapshots (2)**
   ```yaml
   Probable Use:
   ├── Backup of EC2 instance before changes
   ├── AMI creation for environment replication
   ├── Data backup snapshots
   └── Development environment backups
   
   Cost Impact: $0.50-5+/month
   Action: Delete old snapshots, implement lifecycle policy
   ```

### **🔄 Integration with Glue Pipeline Costs**

```yaml
Combined Infrastructure Costs:
├── Glue Pipeline: $179.95/month (from previous analysis)
├── EC2 Resources: $9.30-63+/month (current analysis)
├── Total Infrastructure: $189.25-243+/month
└── Optimization Potential: Save 50-70% with changes

Cost Distribution:
├── NAT Gateways: $97.20/month (largest component)
├── Glue Jobs: $45.50/month
├── EC2 Instance: $8-50+/month (if running)
├── CloudWatch: $18.60/month
└── EBS/Snapshots: $1.30-13+/month
```

---

## ✅ **ACTION CHECKLIST**

### **⏰ TODAY (5 minutes)**
- [ ] Check if EC2 instance is running unnecessarily
- [ ] Stop instance if not needed for active development
- [ ] Review snapshot necessity and delete old ones

### **📅 THIS WEEK (30 minutes)**
- [ ] Set up EC2 cost budget alert ($25/month threshold)
- [ ] Implement instance scheduler for dev environments
- [ ] Review and right-size EBS volumes
- [ ] Set up automated snapshot lifecycle policy

### **📈 THIS MONTH (1 hour)**
- [ ] Implement comprehensive cost monitoring
- [ ] Review instance usage patterns and optimize
- [ ] Consider Reserved Instances if usage is consistent
- [ ] Document cost optimization procedures

---

## 🎯 **ESTIMATED SAVINGS POTENTIAL**

```yaml
Current EC2 Costs: $9.30-63+/month
Optimized EC2 Costs: $2-15/month

Optimization Savings:
├── Stop unnecessary instances: $8-50+/month
├── Delete old snapshots: $0.50-5+/month  
├── Right-size volumes: $2-8+/month
├── Instance scheduling: 60-80% reduction
└── Total Potential Savings: $10.50-63+/month

Annual Savings: $126-756+/year
Combined with Glue optimization: $1,260-1,890+/year total savings
```

---

## 📞 **SUPPORT & NEXT STEPS**

**Immediate Questions to Answer:**
1. Is the EC2 instance actively being used?
2. What are the snapshots backing up?
3. Is the EBS volume attached and necessary?
4. Are these resources part of a development environment?

**Cost Optimization Resources:**
- AWS Cost Explorer for detailed analysis
- AWS Trusted Advisor for recommendations  
- AWS Budgets for ongoing monitoring
- Instance Scheduler for automated management

---

**💡 Remember:** Even small EC2 resources can add up to significant costs over time. The key is regular monitoring and cleanup of unused resources.

**🚨 Critical:** If the EC2 instance is running 24/7 and not needed, stopping it could save $100-600+/year immediately! 