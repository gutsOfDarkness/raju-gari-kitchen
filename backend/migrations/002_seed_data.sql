-- Seed data for Menu Items
INSERT INTO menu_items (id, name, description, price, category, image_url, is_available, created_at, updated_at) VALUES
(gen_random_uuid(), 'Chicken Biryani', 'Aromatic basmati rice cooked with tender chicken and spices.', 35000, 'Main Course', 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8', true, NOW(), NOW()),
(gen_random_uuid(), 'Paneer Butter Masala', 'Cottage cheese cubes in a rich and creamy tomato gravy.', 28000, 'Main Course', 'https://images.unsplash.com/photo-1631452180519-c014fe946bc7', true, NOW(), NOW()),
(gen_random_uuid(), 'Butter Naan', 'Soft and fluffy leavened bread cooked in a tandoor.', 4500, 'Breads', 'https://images.unsplash.com/photo-1610192244261-3f33de3f55e0', true, NOW(), NOW()),
(gen_random_uuid(), 'Gulab Jamun', 'Deep-fried milk solids soaked in sugar syrup.', 12000, 'Dessert', 'https://images.unsplash.com/photo-1593701478530-bf8b958c24cd', true, NOW(), NOW()),
(gen_random_uuid(), 'Mango Lassi', 'Refreshing yogurt drink blended with sweet mango pulp.', 8000, 'Beverages', 'https://images.unsplash.com/photo-1636544525820-2d88c42289f0', true, NOW(), NOW()),
(gen_random_uuid(), 'Chicken 65', 'Spicy, deep-fried chicken dish originating from Chennai.', 25000, 'Starters', 'https://images.unsplash.com/photo-1610057099443-fde8c4d50f91', true, NOW(), NOW());
