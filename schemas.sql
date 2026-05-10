CREATE SCHEMA shop;

CREATE TABLE IF NOT EXISTS shop.users (
	"user_id" SERIAL NOT NULL UNIQUE,
	"email" VARCHAR(255) NOT NULL UNIQUE,
	"name" VARCHAR(255) NOT NULL,
	"phone" VARCHAR(10) NOT NULL UNIQUE,
	"rating" NUMERIC(2,1) NOT NULL DEFAULT 0,
	"created_at" TIMESTAMP NOT NULL DEFAULT now(),
	"updated_at" TIMESTAMP,
	PRIMARY KEY("user_id"),
	CONSTRAINT "check_users_updated_at" CHECK (updated_at >= created_at)
);



CREATE TABLE IF NOT EXISTS shop.products (
	"product_id" SERIAL NOT NULL UNIQUE,
	"seller_id" INTEGER NOT NULL,
	"category" VARCHAR(30) NOT NULL,
	"title" VARCHAR(255) NOT NULL,
	"description" TEXT,
	"price" NUMERIC(10,2) NOT NULL DEFAULT 0,
	"condition" VARCHAR(10) NOT NULL,
	"status" VARCHAR(10) NOT NULL DEFAULT 'active',
	"created_at" TIMESTAMP NOT NULL DEFAULT now(),
	"updated_at" TIMESTAMP,
	"valid_from" TIMESTAMP NOT NULL DEFAULT now(),
	"valid_to" TIMESTAMP,
	"is_current" BOOLEAN NOT NULL DEFAULT TRUE,
	PRIMARY KEY("product_id"),
	CONSTRAINT "check_products_category" CHECK (category IN ('coins', 'watches', 'antiques', 'vinyl_records', 'models', 'stamps', 'art', 'books', 'toys', 'sports_memorabilia', 'other')),
	CONSTRAINT "check_products_condition" CHECK (condition IN ('new', 'like_new', 'good', 'fair', 'poor')),
	CONSTRAINT "check_products_status" CHECK (status IN ('active', 'sold', 'archived')),
	CONSTRAINT "check_products_updated_at" CHECK (updated_at >= created_at),
	CONSTRAINT "check_products_valid_to" CHECK (valid_to >= valid_from)
);

--Для поиска активных товаров по категории и цене
CREATE INDEX idx_products_category_price ON products(category, price) 
WHERE status = 'active';

--Списание старого товара в архив
CREATE OR REPLACE PROCEDURE archive_product(p_product_id INTEGER)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE products
    SET status = 'archived',
        updated_at = NOW()
    WHERE product_id = p_product_id
      AND status = 'active';
    
    IF FOUND THEN
        RAISE NOTICE 'Товар % заархивирован', p_product_id;
    ELSE
        RAISE NOTICE 'Товар % не найден или уже не активен', p_product_id;
    END IF;
END;
$$;

CALL archive_product(25);

--Автообновление updated_at при изменении товара
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();



CREATE TABLE IF NOT EXISTS shop.purchases (
	"purchase_id" SERIAL NOT NULL UNIQUE,
	"product_id" INTEGER NOT NULL,
	"buyer_id" INTEGER NOT NULL,
	"seller_id" INTEGER NOT NULL,
	"amount" NUMERIC(10,2) NOT NULL DEFAULT 0,
	"status" VARCHAR(10) NOT NULL DEFAULT 'pending',
	"created_at" TIMESTAMP NOT NULL DEFAULT now(),
	"paid_at" TIMESTAMP,
	"delivered_at" TIMESTAMP,
	PRIMARY KEY("purchase_id"),
	CONSTRAINT "check_purchases_status" CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'cancelled')),
	CONSTRAINT "check_purchases_paid_at" CHECK (paid_at >= created_at),
	CONSTRAINT "check_purchases_delivered_at" CHECK (delivered_at >= created_at),
	CONSTRAINT "check_buyer_and_seller_id" CHECK (buyer_id <> seller_id)
);

--Для поиска покупок по покупателю с сортировкой по дате
CREATE INDEX idx_purchases_buyer_created ON purchases(buyer_id, created_at DESC);

--Автообновление updated_at при изменении товара для purchases
CREATE TRIGGER trg_purchases_updated_at
BEFORE UPDATE ON purchases
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

--Подсчёт общего количества покупок пользователя
CREATE OR REPLACE FUNCTION get_user_purchase_count(p_user_id INTEGER)
RETURNS INTEGER AS $$
DECLARE
    purchase_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO purchase_count
    FROM purchases
    WHERE buyer_id = p_user_id;
    
    RETURN purchase_count;
END;
$$ LANGUAGE plpgsql;

SELECT user_id, name, get_user_purchase_count(user_id) as total_purchases
FROM users
WHERE user_id = 4;



CREATE TABLE IF NOT EXISTS shop.payments (
	"payment_id" SERIAL NOT NULL UNIQUE,
	"purchase_id" INTEGER NOT NULL,
	"amount" NUMERIC(10,2) NOT NULL DEFAULT 0,
	"method" VARCHAR(20) NOT NULL,
	"status" VARCHAR(10) NOT NULL DEFAULT 'pending',
	"created_at" TIMESTAMP NOT NULL DEFAULT now(),
	PRIMARY KEY("payment_id"),
	CONSTRAINT "check_payments_status" CHECK (status IN ('pending', 'completed', 'failed', 'refunded'))
);

--Очистка старых неудачных платежей
CREATE OR REPLACE PROCEDURE cleanup_failed_payments(p_days_old INTEGER DEFAULT 30)
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM payments
    WHERE status = 'failed'
      AND created_at < NOW() - (p_days_old || ' days')::INTERVAL;
END;
$$;

CALL cleanup_failed_payments(10);



CREATE TABLE IF NOT EXISTS shop.reviews (
	"review_id" SERIAL NOT NULL UNIQUE,
	"purchase_id" INTEGER NOT NULL,
	"reviewer_id" INTEGER NOT NULL,
	"reviewed_id" INTEGER NOT NULL,
	"rating" SMALLINT NOT NULL DEFAULT 0,
	"comment" TEXT,
	"created_at" TIMESTAMP NOT NULL DEFAULT now(),
	PRIMARY KEY("review_id")
);

--Для поиска отзывов по оценке
CREATE INDEX idx_reviews_rating ON reviews(reviewed_id, rating DESC);

--Защита от повторного отзыва на одну покупку
CREATE OR REPLACE FUNCTION prevent_duplicate_review()
RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    existing_review_id INTEGER;
BEGIN
    SELECT review_id INTO existing_review_id
    FROM reviews
    WHERE purchase_id = NEW.purchase_id 
      AND reviewer_id = NEW.reviewer_id;
    
    IF FOUND THEN
        RAISE EXCEPTION 'Вы уже оставили отзыв на эту покупку (review_id = %)', existing_review_id;
    END IF;
    
    IF NEW.reviewer_id = NEW.reviewed_id THEN
        RAISE EXCEPTION 'Нельзя оставить отзыв на самого себя';
    END IF;
    
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_prevent_duplicate_review
BEFORE INSERT ON reviews
FOR EACH ROW
EXECUTE FUNCTION prevent_duplicate_review();

-- Первый отзыв на покупку 1 от пользователя 2
INSERT INTO reviews (purchase_id, reviewer_id, reviewed_id, rating, comment)
VALUES (1, 2, 1, 5, 'Отличный продавец!');

-- Попытка оставить второй отзыв на ту же покупку от того же пользователя
INSERT INTO reviews (purchase_id, reviewer_id, reviewed_id, rating, comment)
VALUES (1, 2, 1, 4, 'Накрутка отзывов');



ALTER TABLE shop.products
ADD FOREIGN KEY("seller_id") REFERENCES shop.users("user_id");
ALTER TABLE shop.purchases
ADD FOREIGN KEY("buyer_id") REFERENCES shop.users("user_id");
ALTER TABLE shop.purchases
ADD FOREIGN KEY("seller_id") REFERENCES shop.users("user_id");
ALTER TABLE shop.purchases
ADD FOREIGN KEY("product_id") REFERENCES shop.products("product_id");
ALTER TABLE shop.payments
ADD FOREIGN KEY("purchase_id") REFERENCES shop.purchases("purchase_id");
ALTER TABLE shop.reviews
ADD FOREIGN KEY("purchase_id") REFERENCES shop.purchases("purchase_id");
ALTER TABLE shop.reviews
ADD FOREIGN KEY("reviewer_id") REFERENCES shop.users("user_id");
ALTER TABLE shop.reviews
ADD FOREIGN KEY("reviewed_id") REFERENCES shop.users("user_id");


--Все активные товары
CREATE OR REPLACE VIEW v_active_products_with_sellers AS
SELECT 
    p.product_id,
    p.title,
    p.category,
    p.price,
    p.condition,
    p.created_at as listed_at,
    u.user_id as seller_id,
    u.name as seller_name,
    u.rating as seller_rating,
    COUNT(r.review_id) as seller_total_reviews,
    ROUND(AVG(CASE WHEN r.reviewed_id = u.user_id THEN r.rating END), 1) as seller_avg_rating
FROM products p
JOIN users u ON p.seller_id = u.user_id
LEFT JOIN reviews r ON u.user_id = r.reviewed_id
WHERE p.status = 'active'
GROUP BY p.product_id, p.title, p.category, p.price, p.condition, 
         p.created_at, u.user_id, u.name, u.rating;


--Ежемесячный отчёт по продажам
CREATE MATERIALIZED VIEW mv_monthly_sales_report AS
SELECT 
    DATE_TRUNC('month', pur.created_at) as month,
    p.category,
    COUNT(DISTINCT pur.purchase_id) as total_orders,
    COUNT(DISTINCT pur.buyer_id) as unique_buyers,
    COUNT(DISTINCT pur.seller_id) as unique_sellers,
    SUM(pur.amount) as revenue,
    ROUND(AVG(pur.amount), 2) as avg_order_value,
    SUM(CASE WHEN pay.status = 'completed' THEN pay.amount ELSE 0 END) as successfully_paid,
    SUM(CASE WHEN pay.status = 'failed' THEN pay.amount ELSE 0 END) as failed_payments,
    COUNT(CASE WHEN pur.status = 'cancelled' THEN 1 END) as cancelled_orders
FROM purchases pur
JOIN products p ON pur.product_id = p.product_id
LEFT JOIN payments pay ON pur.purchase_id = pay.purchase_id
WHERE pur.status IN ('delivered', 'paid', 'shipped', 'cancelled')
GROUP BY DATE_TRUNC('month', pur.created_at), p.category
ORDER BY month DESC, revenue DESC;

CREATE INDEX idx_mv_monthly_sales ON mv_monthly_sales_report(month, category);

REFRESH MATERIALIZED VIEW mv_monthly_sales_report;
