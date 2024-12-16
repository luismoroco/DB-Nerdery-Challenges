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
  FOREIGN KEY (user_type_id) REFERENCES "user_type"(user_type_id) ON DELETE CASCADE
);
CREATE TRIGGER update_user_updated_at BEFORE
UPDATE
  ON "user" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Credentials recovery
CREATE TABLE "user_credential_type" (
  user_credential_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO user_credential_type
VALUES
  (1, 'PASSWORD', 'Password');

CREATE TABLE "user_credential_recovery" (
  user_id BIGINT NOT NULL,
  user_credential_type_id BIGINT NOT NULL,
  token TEXT NOT NULL,
  used_at TIMESTAMP(3) WITH TIME ZONE DEFAULT NULL,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
  FOREIGN KEY (user_credential_type_id) REFERENCES "user_credential_type"(user_credential_type_id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, user_credential_type_id)
);

-- Notification
CREATE TABLE "notification_event_type" (
  notification_event_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT, spec JSONB NOT NULL
);
INSERT INTO notification_event_type
VALUES
  (1, 'PASSWORD_RECOVERY', 'Password recovery', '{}'),
  (2, 'LOW_STOCK', 'Low stock', '{"minimumStock": 3}');

CREATE TABLE "notification_state_type" (
  notification_state_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO notification_state_type
VALUES
  (1, 'PENDING', 'Pending'),
  (2, 'SENT', 'Sent'),
  (3, 'FAILED', 'Failed');

CREATE TABLE "notification_provider" (
  notification_provider_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  label TEXT NOT NULL,
  enabled BOOLEAN DEFAULT FALSE
);
INSERT INTO notification_provider
VALUES
  (1, 'G-MAIL', 'G-Mail', false);

CREATE TABLE "notification" (
  notification_id BIGSERIAL PRIMARY KEY NOT NULL,
  notification_provider_id BIGINT NOT NULL,
  notification_event_type_id BIGINT NOT NULL,
  notification_state_type_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  body JSONB NOT NULL,
  FOREIGN KEY (notification_provider_id) REFERENCES "notification_provider"(notification_provider_id) ON DELETE CASCADE,
  FOREIGN KEY (notification_event_type_id) REFERENCES "notification_event_type"(notification_event_type_id) ON DELETE CASCADE,
  FOREIGN KEY (notification_state_type_id) REFERENCES "notification_state_type"(notification_state_type_id) ON DELETE CASCADE,
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
  name TEXT UNIQUE NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC(12, 2) NOT NULL,
  enabled BOOLEAN DEFAULT TRUE,
  archived BOOLEAN DEFAULT FALSE,
  featured BOOLEAN DEFAULT FALSE,
  stock INT CHECK (stock >= 0) NOT NULL,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
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
  name TEXT UNIQUE NOT NULL,
  featured BOOLEAN,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL
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
  FOREIGN KEY (product_id) REFERENCES "product"(product_id) ON DELETE CASCADE,
  FOREIGN KEY (category_id) REFERENCES "category"(category_id) ON DELETE CASCADE,
  UNIQUE (product_id, category_id)
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
  FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
  FOREIGN KEY (order_state_type_id) REFERENCES "order_state_type"(order_state_type_id) ON DELETE CASCADE
);
CREATE TRIGGER update_order_updated_at BEFORE
UPDATE
  ON "order" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE "order_item" (
  order_item_id BIGSERIAL PRIMARY KEY NOT NULL,
  order_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  name TEXT NOT NULL,
  unit_price NUMERIC(12, 2) NOT NULL,
  quantity INT CHECK (quantity >= 1) NOT NULL,
  FOREIGN KEY (order_id) REFERENCES "order"(order_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES "product"(product_id) ON DELETE CASCADE
);

-- Payment
CREATE TABLE "payment_method_type" (
  payment_method_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO payment_method_type
VALUES
  (1, 'CARD', 'Card');

CREATE TABLE "payment_provider" (
  payment_provider_id BIGINT PRIMARY KEY NOT NULL,
  payment_method_type_id BIGINT NOT NULL,
  name TEXT NOT NULL,
  label TEXT NOT NULL,
  enabled BOOLEAN DEFAULT FALSE,
  FOREIGN KEY (payment_method_type_id) REFERENCES "payment_method_type"(payment_method_type_id) ON DELETE CASCADE
);
INSERT INTO payment_provider
VALUES
  (1, 1, 'STRIPE CHECKOUT', 'Stripe Checkout', false);

CREATE TABLE "payment_state_type" (
  payment_state_type_id BIGINT PRIMARY KEY NOT NULL,
  name TEXT, label TEXT
);
INSERT INTO payment_state_type
VALUES
    (1, 'PENDING', 'Pending'),
    (2, 'PAID', 'Paid'),
    (3, 'FAILED', 'Failed'),
    (4, 'CANCELED', 'Canceled');

CREATE TABLE "payment" (
  payment_id BIGSERIAL PRIMARY KEY NOT NULL,
  order_id BIGINT NOT NULL,
  payment_provider_id BIGINT NOT NULL,
  payment_state_type_id BIGINT NOT NULL,
  initialization_data JSONB,
  transaction_data JSONB,
  created_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  updated_at TIMESTAMP(3) WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP NOT NULL,
  paid_at TIMESTAMP(3) WITH TIME ZONE,
  FOREIGN KEY (order_id) REFERENCES "order"(order_id),
  FOREIGN KEY (payment_provider_id) REFERENCES "payment_provider"(payment_provider_id),
  FOREIGN KEY (payment_state_type_id) REFERENCES "payment_state_type"(payment_state_type_id)
);
CREATE TRIGGER update_payment_updated_at BEFORE
UPDATE
    ON "payment" FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Shopping Cart
CREATE TABLE "shopping_cart" (
  shopping_cart_id BIGSERIAL PRIMARY KEY NOT NULL,
  user_id BIGINT UNIQUE NOT NULL,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id)
);
CREATE TABLE "shopping_cart_item" (
  shopping_cart_item_id BIGSERIAL PRIMARY KEY NOT NULL,
  shopping_cart_id BIGINT NOT NULL,
  product_id BIGINT NOT NULL,
  quantity INT NOT NULL,
  number INT NOT NULL,
  FOREIGN KEY (shopping_cart_id) REFERENCES "shopping_cart"(shopping_cart_id) ON DELETE CASCADE,
  FOREIGN KEY (product_id) REFERENCES "product"(product_id) ON DELETE CASCADE
);

-- Like
CREATE TABLE "product_like" (
  product_id BIGINT NOT NULL,
  user_id BIGINT NOT NULL,
  FOREIGN KEY (product_id) REFERENCES "product"(product_id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES "user"(user_id) ON DELETE CASCADE,
  PRIMARY KEY (product_id, user_id)
);
