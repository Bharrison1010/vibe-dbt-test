with raw as (
    select _line, column_0 as txt
    from {{ source("sftp_raw", "commercial_alliance_raw") }}
),

sectioned as (
    select
        _line,
        txt,
        last_value(case when txt like ''SECTION %'' then txt end ignore nulls)
            over (order by _line rows between unbounded preceding and current row) as section_label
    from raw
),

parsed as (
    select
        _line,
        section_label,
        regexp_substr(txt, ''^(CA-[0-9]+)'', 1, 1, ''e'', 1)   as note_number,
        split_part(txt, '','', 2)                              as borrower_name,
        regexp_substr(txt, ''"([0-9,.]+)"'', 1, 1, ''e'', 1)   as current_balance_txt,
        regexp_substr(txt, ''"([0-9,.]+)"'', 1, 2, ''e'', 1)   as available_credit_txt,
        regexp_substr(txt, ''([0-9.]+)%'', 1, 1, ''e'', 1)     as participation_pct_txt,
        regexp_substr(txt, ''([0-9.]+)%'', 1, 2, ''e'', 1)     as interest_rate_txt,
        regexp_substr(txt, ''"([0-9,.]+)"'', 1, 3, ''e'', 1)   as interest_charged_txt,
        split_part(txt, '','', -1)                             as payment_status
    from sectioned
    where txt like ''CA-%''
)

select
    note_number,
    borrower_name,
    replace(current_balance_txt, '','', '''')::number(14,2)  as current_balance,
    replace(available_credit_txt, '','', '''')::number(14,2) as available_credit,
    participation_pct_txt::number(8,4) / 100                 as participation_pct,
    interest_rate_txt::number(8,4) / 100                     as interest_rate,
    replace(interest_charged_txt, '','', '''')::number(14,2) as interest_charged_mtd,
    payment_status,
    section_label
from parsed
