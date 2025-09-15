#!/bin/bash

# AWS Cost Alert Setup Script
# Sets up budget alerts for EC2 and total AWS costs

set -e

echo "🔍 Setting up AWS Cost Alerts..."
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "✅ AWS Account ID: $ACCOUNT_ID"

# Prompt for email address
echo ""
echo "📧 Please enter your email address for budget alerts:"
read -p "Email: " EMAIL_ADDRESS

if [[ -z "$EMAIL_ADDRESS" ]]; then
    echo "❌ Error: Email address is required"
    exit 1
fi

echo ""
echo "📝 Updating notification files with your email..."

# Update notification files with user's email
sed -i.bak "s/your-email@example.com/$EMAIL_ADDRESS/g" budget-notifications-ec2.json
sed -i.bak "s/your-email@example.com/$EMAIL_ADDRESS/g" budget-notifications-total.json

echo "✅ Email updated in notification files"

echo ""
echo "💰 Creating budgets..."

# Create EC2 Budget ($25/month)
echo "📊 Creating EC2 budget ($25/month)..."
aws budgets create-budget \
    --account-id "$ACCOUNT_ID" \
    --budget file://budget-config-ec2.json \
    --notifications-with-subscribers file://budget-notifications-ec2.json

if [[ $? -eq 0 ]]; then
    echo "✅ EC2 budget created successfully!"
else
    echo "⚠️  EC2 budget may already exist or there was an error"
fi

# Create Total AWS Budget ($200/month)
echo ""
echo "📊 Creating total AWS budget ($200/month)..."
aws budgets create-budget \
    --account-id "$ACCOUNT_ID" \
    --budget file://budget-config-total.json \
    --notifications-with-subscribers file://budget-notifications-total.json

if [[ $? -eq 0 ]]; then
    echo "✅ Total AWS budget created successfully!"
else
    echo "⚠️  Total AWS budget may already exist or there was an error"
fi

echo ""
echo "🎉 Cost alert setup complete!"
echo ""
echo "📋 Summary of budgets created:"
echo "   • EC2 Monthly Budget: $25"
echo "     - Alert at 80% ($20)"
echo "     - Alert at 100% ($25)"
echo "     - Forecast alert when trending over budget"
echo ""
echo "   • Total AWS Monthly Budget: $200" 
echo "     - Alert at 50% ($100)"
echo "     - Alert at 80% ($160)"
echo "     - Alert at 100% ($200)"
echo "     - Forecast alert when trending over budget"
echo ""
echo "📧 All alerts will be sent to: $EMAIL_ADDRESS"
echo ""
echo "🔍 You can view your budgets in the AWS Console:"
echo "   https://console.aws.amazon.com/billing/home#/budgets"
echo ""
echo "💡 Tip: You'll receive email confirmations for the budget subscriptions."
echo "    Make sure to confirm them to start receiving alerts!"

# Cleanup backup files
rm -f budget-notifications-ec2.json.bak budget-notifications-total.json.bak

echo ""
echo "✅ Setup complete! Your cost alerts are now active." 