-- Task 1: SQL data preprocessing in SQLite.
-- Python's runner registers REGEXP, REGEXP_REPLACE and REGEXP_SUBSTR.

DROP VIEW IF EXISTS v_task1_quality_summary;
DROP VIEW IF EXISTS v_task1_before_after;
DROP TABLE IF EXISTS user_standard_data;

DELETE FROM user_raw_data;

INSERT INTO user_raw_data
    (raw_name, raw_phone, raw_email, raw_register_time, raw_address, raw_age, raw_remark)
VALUES
    ('张三', '13800138000', 'zhangsan@163.com', '2024-01-15 09:30:00', '北京市朝阳区建国路88号', '25', '正常用户'),
    (' 李四 ', '13912345678', 'lisi@gmail.com', '2024/02/20', '上海市浦东新区张江高科技园区', '30岁', 'VIP客户'),
    ('王 五', '137-8888-9999', 'wangwu@qq..com', '2024.03.10', '广州市天河区珠江新城', '32', ' 测试用户 '),
    ('Zhao Liu', ' 13677778888 ', 'zhaoliu123', '2024-04-05', '深圳市南山区科技园', '未知', '无备注'),
    ('钱七', '8613566667777', 'qianqi@outlook.com', '2024/05/12 10:00', '杭州市西湖区西溪湿地', '28', '特殊需求'),
    ('孙八', '1345555', 'sunba@126.com', '2024.06.18 14:20', '成都市高新区天府大道', '35岁', '离职'),
    ('周九', '133abc123456', 'zhoujiu@', '2024-07-22', '武汉市洪山区光谷广场', '22', '新用户'),
    ('吴十', '13211112222', 'WU_SHI@@qq.com', '2024/08/30', '重庆市渝中区解放碑', '29', '老用户'),
    ('郑十一', '13100001111', 'zhengeshiyi123@', '2024.09.05', '西安市雁塔区高新区', '31', 'NULL'),
    ('王十二', '13099998888', 'wangshier@163.com', '2024年10月01日', '长沙市岳麓区大学城', '27', '无'),
    ('李十三', '12988887777', 'lisan@qq.com', '2024-13-01', '青岛市市南区香港中路', '33岁', '测试'),
    ('张十四', '', 'zhangsi@126.com', '', '昆明市五华区南屏街', '未知', '');

CREATE TABLE user_standard_data AS
WITH base_clean AS (
    SELECT
        id,
        raw_name,
        raw_phone,
        raw_email,
        raw_register_time,
        raw_address,
        raw_age,
        raw_remark,
        REGEXP_REPLACE(TRIM(raw_name), '\s+', '') AS cleaned_name,
        REGEXP_REPLACE(COALESCE(raw_phone, ''), '[^0-9]', '') AS phone_digits_raw,
        LOWER(REGEXP_REPLACE(TRIM(COALESCE(raw_email, '')), '\s+', '')) AS email_clean,
        TRIM(COALESCE(raw_address, '')) AS address_clean,
        REGEXP_REPLACE(COALESCE(raw_age, ''), '[^0-9]', '') AS age_digits,
        TRIM(COALESCE(raw_remark, '')) AS remark_clean,
        REGEXP_SUBSTR(raw_register_time, '[0-9]+', 1) AS date_year,
        REGEXP_SUBSTR(raw_register_time, '[0-9]+', 2) AS date_month,
        REGEXP_SUBSTR(raw_register_time, '[0-9]+', 3) AS date_day
    FROM user_raw_data
),
normalized AS (
    SELECT
        *,
        CASE
            WHEN SUBSTR(phone_digits_raw, 1, 2) = '86' AND LENGTH(phone_digits_raw) = 13
                THEN SUBSTR(phone_digits_raw, 3)
            ELSE phone_digits_raw
        END AS phone_digits,
        SAFE_DATE(date_year, date_month, date_day) AS parsed_register_date
    FROM base_clean
),
validated AS (
    SELECT
        id,
        raw_name,
        raw_phone,
        raw_email,
        raw_register_time,
        raw_address,
        raw_age,
        raw_remark,
        CASE
            WHEN cleaned_name REGEXP '^[一-龥]{2,10}$' THEN cleaned_name
            ELSE '无效姓名'
        END AS user_name,
        CASE
            WHEN phone_digits REGEXP '^1[3-9][0-9]{9}$' THEN phone_digits
            ELSE '无效手机号'
        END AS user_phone,
        CASE
            WHEN email_clean REGEXP '^[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)+$'
                 AND NOT (email_clean REGEXP '\.\.')
                 AND NOT (email_clean REGEXP '@@')
                THEN email_clean
            ELSE '无效邮箱'
        END AS user_email,
        CASE
            WHEN email_clean REGEXP '^[a-z0-9._%+-]+@[a-z0-9-]+(\.[a-z0-9-]+)+$'
                 AND NOT (email_clean REGEXP '\.\.')
                 AND NOT (email_clean REGEXP '@@')
                THEN SUBSTR(email_clean, INSTR(email_clean, '@') + 1)
            ELSE '无效域名'
        END AS email_domain,
        CASE
            WHEN parsed_register_date BETWEEN '2024-01-01' AND '2024-12-31'
                THEN parsed_register_date
            ELSE '无效日期'
        END AS register_date,
        address_clean AS user_address,
        SUBSTR(address_clean, 1, 10) AS short_address,
        CASE
            WHEN INSTR(address_clean, '市') > 0 THEN SUBSTR(address_clean, 1, INSTR(address_clean, '市'))
            WHEN INSTR(address_clean, '省') > 0 THEN SUBSTR(address_clean, 1, INSTR(address_clean, '省'))
            ELSE '未知城市'
        END AS city_name,
        CASE
            WHEN age_digits = '' THEN '未知年龄'
            ELSE age_digits
        END AS user_age,
        CASE
            WHEN remark_clean = '' OR UPPER(remark_clean) = 'NULL' THEN '无备注'
            ELSE remark_clean
        END AS user_remark
    FROM normalized
)
SELECT * FROM validated;

CREATE VIEW v_task1_before_after AS
SELECT
    id,
    raw_name,
    user_name,
    raw_phone,
    user_phone,
    raw_email,
    user_email,
    email_domain,
    raw_register_time,
    register_date,
    raw_address,
    user_address,
    short_address,
    city_name,
    raw_age,
    user_age,
    raw_remark,
    user_remark
FROM user_standard_data
ORDER BY id;

CREATE VIEW v_task1_quality_summary AS
SELECT 'invalid_name' AS metric, COUNT(*) AS value
FROM user_standard_data
WHERE user_name = '无效姓名'
UNION ALL
SELECT 'invalid_phone', COUNT(*)
FROM user_standard_data
WHERE user_phone = '无效手机号'
UNION ALL
SELECT 'invalid_email', COUNT(*)
FROM user_standard_data
WHERE user_email = '无效邮箱'
UNION ALL
SELECT 'invalid_date', COUNT(*)
FROM user_standard_data
WHERE register_date = '无效日期'
UNION ALL
SELECT 'unknown_age', COUNT(*)
FROM user_standard_data
WHERE user_age = '未知年龄'
UNION ALL
SELECT 'empty_remark_after_cleaning', COUNT(*)
FROM user_standard_data
WHERE user_remark = '无备注';
