{#
  Agent spec + deploy wrapper for "sales_agent".

  Deploy (create or replace):   dbt run-operation deploy_sales_agent
  Zero-downtime live update:    dbt run-operation deploy_sales_agent --args '{alter: true}'

  The <<DATABASE>>, <<SCHEMA>>, and <<WAREHOUSE>> tokens are substituted with
  the active environment's target values by create_agent / alter_agent.
#}
{% macro deploy_sales_agent(alter=false) %}
{%- set spec -%}
models:
  orchestration: auto

orchestration:
  budget:
    seconds: 60
    tokens: 16000

instructions:
  response: >
    You are a sales analytics assistant. Lead with the direct answer, then
    provide supporting detail. Use a table for multi-row results. Include units
    and state the time period covered. Round currency to 2 decimal places.
  orchestration: >
    For quantitative questions about orders, products, revenue, or sales
    performance, use the Analyst tool. If no time period is given, default to
    the most recent 30 days. If a query returns no rows, say so and suggest a
    related question the user could try.
  sample_questions:
    - question: "What is the total revenue by region?"
    - question: "What are the top selling products?"
    - question: "Show me the monthly revenue trend"
    - question: "How many orders were cancelled last month?"

tools:
  - tool_spec:
      type: "cortex_analyst_text_to_sql"
      name: "Analyst"
      description: >
        Answers quantitative questions about sales, orders, products, and
        revenue. Covers order-level and line-item-level data including
        order totals, quantities, discounts, channels, regions, and product
        categories. Approximately 12 months of history. Use for any question
        about revenue, units sold, order counts, averages, or breakdowns by
        region/channel/product. Do NOT use for questions about employees, HR,
        or topics outside of sales data.

tool_resources:
  Analyst:
    semantic_view: "<<DATABASE>>.<<SCHEMA>>.SV_SALES"
    execution_environment:
      type: warehouse
      warehouse: <<WAREHOUSE>>
{%- endset -%}

  {% if alter %}
    {{ alter_agent('sales_agent', spec) }}
  {% else %}
    {{ create_agent('sales_agent', spec) }}
  {% endif %}
{% endmacro %}
