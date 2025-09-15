# 💰 AWS Costing - Cost Management & Optimization

This folder contains all cost analysis, monitoring, and optimization resources for the AWS Glue ETL Pipeline project.

---

## 📁 **FOLDER CONTENTS**

### **📊 Cost Analysis Reports**

| File | Purpose | Contents |
|------|---------|-----------|
| **`AWS_Cost_Analysis.md`** | Comprehensive cost analysis | Detailed breakdown by service, optimization recommendations |
| **`Cost_Summary_Executive.md`** | Executive summary | High-level cost overview for stakeholders |
| **`EC2_Resources_Cost_Analysis.md`** | EC2-specific cost analysis | EC2 instances, EBS volumes, snapshots cost breakdown |

### **🔔 Budget Alert Configuration**

| File | Purpose | Usage |
|------|---------|--------|
| **`setup-cost-alerts.sh`** | **Main setup script** | **Run this to set up all budget alerts** |
| **`budget-config-ec2.json`** | EC2 budget configuration | $25/month budget for EC2 services |
| **`budget-config-total.json`** | Total AWS budget config | $200/month budget for all AWS services |
| **`budget-notifications-ec2.json`** | EC2 alert settings | Email notifications for EC2 budget |
| **`budget-notifications-total.json`** | Total AWS alert settings | Email notifications for total budget |

### **🛠️ Cost Analysis Tools**

| Directory | Purpose | Tools |
|-----------|---------|-------|
| **`.infracost/`** | Infrastructure cost analysis | Terraform cost estimation tools |

---

## 🚀 **QUICK START**

### **Set Up Cost Alerts (2 minutes)**
```bash
cd "aws costing"
./setup-cost-alerts.sh
```

**What this does:**
- ✅ Creates $25/month EC2 budget with alerts
- ✅ Creates $200/month total AWS budget with alerts  
- ✅ Sets up email notifications
- ✅ Configures forecast alerts

### **Review Cost Analysis**
```bash
# Read comprehensive cost analysis
open AWS_Cost_Analysis.md

# Executive summary for stakeholders
open Cost_Summary_Executive.md

# EC2-specific costs
open EC2_Resources_Cost_Analysis.md
```

---

## 💡 **KEY INSIGHTS & RECOMMENDATIONS**

### **🔴 HIGH-IMPACT OPTIMIZATIONS**

1. **Remove NAT Gateways** → **Save $1,134/year**
   - Currently costing $97.20/month (54% of total)
   - Replace with VPC endpoints
   - Immediate 52% cost reduction

2. **Optimize EC2 Resources** → **Save $126-756/year**
   - Stop unnecessary instances
   - Delete old snapshots (~$3.20/month)
   - Right-size EBS volumes

3. **Monitor & Alert** → **Prevent cost surprises**
   - $25 EC2 budget alert
   - $200 total AWS budget alert
   - Proactive cost management

### **📊 Current Cost Breakdown**

```yaml
Monthly Costs (Current):
├── NAT Gateways: $97.20 (54%) ⚠️ OPTIMIZE
├── AWS Glue: $45.50 (25%)
├── CloudWatch: $18.60 (10%)
├── EC2 Storage: $7.20 (4%)
├── Other: $11.45 (7%)
└── TOTAL: $179.95/month

Optimized Potential:
└── TOTAL: $85.45/month (52% savings)
```

---

## 🔧 **MANUAL BUDGET SETUP**

If you prefer manual setup instead of the script:

### **1. Get Account ID**
```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
```

### **2. Update Email in Config Files**
```bash
# Replace with your email
sed -i 's/your-email@example.com/YOUR_EMAIL/g' budget-notifications-*.json
```

### **3. Create Budgets**
```bash
# EC2 Budget ($25/month)
aws budgets create-budget \
  --account-id $ACCOUNT_ID \
  --budget file://budget-config-ec2.json \
  --notifications-with-subscribers file://budget-notifications-ec2.json

# Total AWS Budget ($200/month)  
aws budgets create-budget \
  --account-id $ACCOUNT_ID \
  --budget file://budget-config-total.json \
  --notifications-with-subscribers file://budget-notifications-total.json
```

---

## 📈 **MONITORING & MAINTENANCE**

### **View Budgets**
- **AWS Console**: https://console.aws.amazon.com/billing/home#/budgets
- **CLI**: `aws budgets describe-budgets`

### **Update Budget Limits**
```bash
# Update EC2 budget limit
aws budgets update-budget \
  --account-id $ACCOUNT_ID \
  --budget-name "EC2-Monthly-Budget" \
  --new-budget file://budget-config-ec2.json
```

### **Monitor Current Costs**
```bash
# Current month spending
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost
```

---

## 🎯 **OPTIMIZATION CHECKLIST**

### **⏰ Immediate Actions (Today)**
- [ ] Run `./setup-cost-alerts.sh` to set up budget alerts
- [ ] Review NAT Gateway usage and plan removal
- [ ] Check EC2 instance states (ensure stopped if not needed)
- [ ] Delete unnecessary EBS snapshots

### **📅 This Week**
- [ ] Remove NAT Gateways (save $94.50/month)
- [ ] Implement VPC endpoints as replacement
- [ ] Set up automated snapshot lifecycle policies
- [ ] Review and right-size EBS volumes

### **📊 This Month**
- [ ] Implement comprehensive cost monitoring
- [ ] Set up automated resource cleanup
- [ ] Review usage patterns and optimize accordingly
- [ ] Document cost optimization procedures

---

## 📞 **SUPPORT & RESOURCES**

### **Cost Optimization Tools**
- **AWS Cost Explorer**: Detailed cost analysis
- **AWS Trusted Advisor**: Automated recommendations
- **AWS Budgets**: Proactive cost monitoring
- **AWS Cost Anomaly Detection**: Unusual spending alerts

### **Documentation**
- All analysis files contain detailed explanations
- Setup scripts include comprehensive error handling
- Budget configurations are well-documented

### **Next Steps**
1. **Set up alerts**: Run the setup script
2. **Review analysis**: Read the cost analysis reports
3. **Implement optimizations**: Follow the recommendations
4. **Monitor regularly**: Check budgets monthly

---

**💡 Remember**: Proactive cost management is key to avoiding AWS bill surprises. The budget alerts will help you stay on track!

**🚨 Priority**: Remove NAT Gateways first for immediate 52% cost reduction ($1,134/year savings). 