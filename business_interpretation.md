# Part 3 — Written Business Interpretation

**1. What are the top 3 business insights?**

- **Early subscriber growth followed by a plateau**: From January to April, the product shows steady growth. Active subscribers increase from 4 to 17, and Monthly Recurring Revenue (MRR) rises from €140 to €550. However, after April the number of subscribers stabilizes around 16, suggesting that growth slowed or stopped during the later months.
- **Product engagement decreases over time**: At the beginning of the year, all active subscribers are using the product, with engagement at 100% in January. However, it declines to 50% in February, 46% in March, and 18% by April. This suggests that users became less active over time.
- **Revenue remains stable despite lower engagement**: Even though product usage decreases, MRR remains stable at €500 from May onward. This indicates that subscribers continued paying for the product even though activity levels were dropping.

**2. What metric do you trust the least and why?**

**Product Engagement (usage_proxy_pct)**
The dataset shows 0% engagement for several months while there are still active subscribers. In a real product environment, it would be somewhat unusual for all users to completely stop generating events.

Because of this, I would want to confirm whether the event tracking is complete and reliable before relying heavily on this metric.

**3. What data would you ask for next to improve decision-making?**

- **Marketing or acquisition data**: This could help explain why new subscriber growth slows after April.
- **More detailed product usage data**: Knowing which features users interact with could help identify why engagement declined.
- **Customer churn or cancellation reasons**: Understanding why users cancel (or stay subscribed despite low usage) would provide more insight into customer behavior.
