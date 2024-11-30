-- Util
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE
OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = CURRENT_TIMESTAMP;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- User
CREATE TABLE "user_type" (
  user_type_id BIGINT PRIMARY KEY, name TEXT,
  label TEXT
);
INSERT INTO user_type
VALUES
  (1, 'MANAGER', 'Manager'),
  (2, 'CLIENT', 'Client');

CREATE TABLE "user" (
  user_id BIGSERIAL PRIMARY KEY NOT NULL,
  user_type_id BIGINT NOT NULL,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password TEXT NOT NULL,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  FOREIGN KEY (user_type_id) REFERENCES "user_type"(user_type_id)
);
CREATE TRIGGER update_user_updated_at BEFORE
UPDATE
  ON "user" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Notification
CREATE TABLE "notification_event_type" (
  notification_event_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO notification_event_type
VALUES
  (1, 'PASSWORD_RECOVERY', 'Password recovery'),
  (2, 'LOW_STOCK', 'Low stock');

CREATE TABLE "notification_state_type" (
  notification_state_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO notification_state_type
VALUES
  (1, 'PENDING', 'Pending'),
  (2, 'SENT', 'Sent'),
  (3, 'FAILED', 'Failed');

CREATE TABLE "notification_processor" (
  notification_processor_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL, label TEXT NOT NULL
);
INSERT INTO notification_processor
VALUES
  (1, 'G-MAIL', 'G-Mail');

CREATE TABLE "notification_provider" (
  notification_provider_id BIGSERIAL PRIMARY KEY NOT NULL,
  notification_processor_id BIGINT NOT NULL,
  server_parameters JSONB NOT NULL,
  enabled BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (notification_processor_id) REFERENCES "notification_processor"(notification_processor_id)
);

CREATE TABLE "notification" (
  notification_id BIGSERIAL PRIMARY KEY NOT NULL,
  notification_provider_id BIGINT NOT NULL,
  notification_event_type_id BIGINT NOT NULL,
  notification_state_type_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  body JSONB NOT NULL,
  FOREIGN KEY (notification_provider_id) REFERENCES "notification_provider"(notification_provider_id),
  FOREIGN KEY (notification_event_type_id) REFERENCES "notification_event_type"(notification_event_type_id),
  FOREIGN KEY (notification_state_type_id) REFERENCES "notification_state_type"(notification_state_type_id),
  FOREIGN KEY (user_id) REFERENCES "user"(user_id)
);

-- File
CREATE TABLE "file_type" (
  file_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO file_type
VALUES
  (1, 'IMAGE', 'Image');

CREATE TABLE "storage_provider" (
  storage_provider_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO storage_provider
VALUES
  (1, 'S3', 'Amazon S3');

CREATE TABLE "file" (
  file_id BIGINT PRIMARY KEY NOT NULL,
  storage_provider_id BIGINT NOT NULL,
  file_type_id BIGINT NOT NULL,
  url TEXT NOT NULL,
  FOREIGN KEY (storage_provider_id) REFERENCES "storage_provider"(storage_provider_id),
  FOREIGN KEY (file_type_id) REFERENCES "file_type"(file_type_id)
);

-- Currency
CREATE TABLE "currency" (
  currency_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO currency
VALUES
  (1, 'PEN', 'Peruvian Soles');

-- Products
CREATE TABLE "product" (
  product_id BIGSERIAL PRIMARY KEY NOT NULL,
  user_id BIGINT NOT NULL,
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC(12, 2) NOT NULL,
  enabled BOOLEAN DEFAULT TRUE,
  archived BOOLEAN DEFAULT FALSE,
  featured BOOLEAN DEFAULT FALSE,
  stock INT CHECK (stock >= 0),
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id),
  UNIQUE (user_id, name)
);
CREATE INDEX index_product_on_name ON product USING gin (name gin_trgm_ops);
CREATE TRIGGER update_product_updated_at BEFORE
UPDATE
  ON "product" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE "product_resource" (
  product_resource_id BIGSERIAL PRIMARY KEY NOT NULL,
  product_id BIGINT NOT NULL,
  file_id BIGINT NOT NULL,
  number INT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES "product"(product_id),
  FOREIGN KEY (file_id) REFERENCES "file"(file_id)
);

-- Category
CREATE TABLE "category" (
  category_id BIGSERIAL PRIMARY KEY NOT NULL,
  user_id BIGINT NOT NULL,
  name TEXT NOT NULL,
  featured BOOLEAN,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id),
  UNIQUE (user_id, name)
);
CREATE TRIGGER update_category_updated_at BEFORE
UPDATE
  ON "category" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE "category_resource" (
  category_resource_id BIGSERIAL PRIMARY KEY NOT NULL,
  category_id BIGINT NOT NULL,
  file_id BIGINT NOT NULL,
  number INT NOT NULL,
  FOREIGN KEY (category_id) REFERENCES "category"(category_id),
  FOREIGN KEY (file_id) REFERENCES "file"(file_id)
);

CREATE TABLE "category_product" (
  product_id BIGINT NOT NULL,
  category_id BIGINT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES "product"(product_id),
  FOREIGN KEY (category_id) REFERENCES "category"(category_id),
  UNIQUE (product_id, category_id)
);

-- Payment
CREATE TABLE "payment_processor" (
  payment_processor_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL, label TEXT NOT NULL
);
INSERT INTO payment_processor
VALUES
  (1, 'STRIPE CHECKOUT', 'Stripe Checkout');

CREATE TABLE "payment_provider" (
  payment_provider_id BIGSERIAL PRIMARY KEY NOT NULL,
  payment_processor_id BIGINT NOT NULL,
  currency_id BIGINT NOT NULL,
  file_id BIGINT NOT NULL,
  server_parameters JSONB NOT NULL,
  client_parameters JSONB NOT NULL,
  enabled BOOLEAN,
  FOREIGN KEY (payment_processor_id) REFERENCES "payment_processor"(payment_processor_id),
  FOREIGN KEY (currency_id) REFERENCES "currency"(currency_id),
  FOREIGN KEY (file_id) REFERENCES "file"(file_id)
);

-- Order
CREATE TABLE "order_state_type" (
  order_state_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO order_state_type
VALUES
  (1, 'PENDING', 'Pending'),
  (2, 'PAID', 'Paid'),
  (3, 'FAILED', 'Failed');

CREATE TABLE "order" (
  order_id BIGSERIAL PRIMARY KEY NOT NULL,
  user_id BIGINT NOT NULL,
  order_state_type_id BIGINT NOT NULL,
  amount NUMERIC(12, 2) NOT NULL,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  paid_at TIMESTAMP(3) WITH TIME ZONE,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id),
  FOREIGN KEY (order_state_type_id) REFERENCES "order_state_type"(order_state_type_id)
);
CREATE TRIGGER update_order_updated_at BEFORE
UPDATE
  ON "order" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE "invoice" (
  invoice_id BIGSERIAL PRIMARY KEY NOT NULL,
  order_id BIGINT UNIQUE NOT NULL,
  payment_provider_id BIGINT NOT NULL,
  currency_id BIGINT NOT NULL,
  description TEXT,
  FOREIGN KEY (order_id) REFERENCES "order"(order_id),
  FOREIGN KEY (payment_provider_id) REFERENCES "payment_provider"(payment_provider_id),
  FOREIGN KEY (currency_id) REFERENCES "currency"(currency_id)
);

CREATE TABLE "invoice_line_type" (
  invoice_line_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL, label TEXT NOT NULL
);
INSERT INTO invoice_line_type
VALUES
  (1, 'PRODUCT', 'Product');

CREATE TABLE "invoice_line" (
  invoice_line_id BIGSERIAL PRIMARY KEY NOT NULL,
  invoice_id BIGINT NOT NULL,
  invoice_line_type_id BIGINT NOT NULL,
  product_id BIGINT,
  unit_price NUMERIC(12, 2),
  quantity INT,
  FOREIGN KEY (invoice_id) REFERENCES "invoice"(invoice_id),
  FOREIGN KEY (invoice_line_type_id) REFERENCES "invoice_line_type"(invoice_line_type_id),
  FOREIGN KEY (product_id) REFERENCES "product"(product_id)
);

-- Shopping Cart
CREATE TABLE "shopping_cart" (
  shopping_cart_id BIGSERIAL PRIMARY KEY NOT NULL,
  user_id BIGINT UNIQUE NOT NULL,
  metadata JSONB NOT NULL,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id)
);

-- Like
CREATE TABLE "product_like" (
  product_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES "product"(product_id),
  FOREIGN KEY (user_id) REFERENCES "user"(user_id),
  UNIQUE (product_id, user_id)
);
