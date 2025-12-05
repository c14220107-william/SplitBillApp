-- ============================================
-- SPLITBILLERS DATABASE SCHEMA
-- ============================================

-- 1. Drop existing objects if any (untuk clean install)
DROP TYPE IF EXISTS bill_status CASCADE;
DROP TYPE IF EXISTS payment_status CASCADE;
DROP TABLE IF EXISTS public.item_assignments CASCADE;
DROP TABLE IF EXISTS public.bill_items CASCADE;
DROP TABLE IF EXISTS public.bill_members CASCADE;
DROP TABLE IF EXISTS public.bills CASCADE;
-- profiles sudah ada dari auth setup

-- 2. Create Enum Types
CREATE TYPE bill_status AS ENUM ('DRAFT', 'FINAL', 'COMPLETED');
CREATE TYPE payment_status AS ENUM ('UNPAID', 'PENDING', 'PAID');

-- 3. Profiles table sudah ada, tapi pastikan struktur benar
-- Jika belum ada, uncomment baris di bawah:
/*
CREATE TABLE public.profiles (
  id uuid REFERENCES auth.users ON DELETE CASCADE PRIMARY KEY,
  email text,
  full_name text,
  avatar_url text,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);
*/

-- 4. Bills Table (Header Tagihan)
CREATE TABLE public.bills (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  created_by uuid REFERENCES public.profiles(id) NOT NULL,
  title text NOT NULL,
  date date DEFAULT current_date,
  tax_percent numeric DEFAULT 0,
  service_percent numeric DEFAULT 0,
  status bill_status DEFAULT 'DRAFT',
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 5. Bill Members Table (Peserta/Participants)
CREATE TABLE public.bill_members (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  bill_id uuid REFERENCES public.bills(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) NOT NULL,
  final_total numeric DEFAULT 0,
  status payment_status DEFAULT 'UNPAID',
  proof_url text,
  joined_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(bill_id, user_id) -- Prevent duplicate members in same bill
);

-- 6. Bill Items Table (Menu/Item Pesanan)
CREATE TABLE public.bill_items (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  bill_id uuid REFERENCES public.bills(id) ON DELETE CASCADE NOT NULL,
  name text NOT NULL,
  price numeric NOT NULL,
  quantity int DEFAULT 1,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 7. Item Assignments Table (Siapa Makan Apa)
CREATE TABLE public.item_assignments (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  item_id uuid REFERENCES public.bill_items(id) ON DELETE CASCADE NOT NULL,
  user_id uuid REFERENCES public.profiles(id) NOT NULL,
  assigned_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE(item_id, user_id) -- Prevent double assignment
);

-- ============================================
-- INDEXES for Performance
-- ============================================

CREATE INDEX idx_bills_created_by ON public.bills(created_by);
CREATE INDEX idx_bills_status ON public.bills(status);
CREATE INDEX idx_bill_members_bill_id ON public.bill_members(bill_id);
CREATE INDEX idx_bill_members_user_id ON public.bill_members(user_id);
CREATE INDEX idx_bill_items_bill_id ON public.bill_items(bill_id);
CREATE INDEX idx_item_assignments_item_id ON public.item_assignments(item_id);
CREATE INDEX idx_item_assignments_user_id ON public.item_assignments(user_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_assignments ENABLE ROW LEVEL SECURITY;

-- Bills Policies
CREATE POLICY "Users can view bills they created or are member of"
  ON public.bills FOR SELECT
  USING (
    auth.uid() = created_by OR
    EXISTS (
      SELECT 1 FROM public.bill_members
      WHERE bill_members.bill_id = bills.id
      AND bill_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can create their own bills"
  ON public.bills FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Only bill creator can update their bills"
  ON public.bills FOR UPDATE
  USING (auth.uid() = created_by);

CREATE POLICY "Only bill creator can delete their bills"
  ON public.bills FOR DELETE
  USING (auth.uid() = created_by);

-- Bill Members Policies
CREATE POLICY "Users can view members of bills they're part of"
  ON public.bill_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND (bills.created_by = auth.uid() OR 
           EXISTS (SELECT 1 FROM public.bill_members bm2 
                   WHERE bm2.bill_id = bills.id 
                   AND bm2.user_id = auth.uid()))
    )
  );

CREATE POLICY "Bill creator can add members"
  ON public.bill_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Bill creator and member itself can update member info"
  ON public.bill_members FOR UPDATE
  USING (
    user_id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND bills.created_by = auth.uid()
    )
  );

-- Bill Items Policies
CREATE POLICY "Users can view items of bills they're part of"
  ON public.bill_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_items.bill_id
      AND (bills.created_by = auth.uid() OR 
           EXISTS (SELECT 1 FROM public.bill_members 
                   WHERE bill_members.bill_id = bills.id 
                   AND bill_members.user_id = auth.uid()))
    )
  );

CREATE POLICY "Only bill creator can manage items"
  ON public.bill_items FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_items.bill_id
      AND bills.created_by = auth.uid()
    )
  );

-- Item Assignments Policies
CREATE POLICY "Users can view assignments of bills they're part of"
  ON public.item_assignments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_items
      JOIN public.bills ON bills.id = bill_items.bill_id
      WHERE bill_items.id = item_assignments.item_id
      AND (bills.created_by = auth.uid() OR 
           EXISTS (SELECT 1 FROM public.bill_members 
                   WHERE bill_members.bill_id = bills.id 
                   AND bill_members.user_id = auth.uid()))
    )
  );

CREATE POLICY "Only bill creator can manage item assignments"
  ON public.item_assignments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_items
      JOIN public.bills ON bills.id = bill_items.bill_id
      WHERE bill_items.id = item_assignments.item_id
      AND bills.created_by = auth.uid()
    )
  );

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Triggers for updated_at
CREATE TRIGGER update_bills_updated_at BEFORE UPDATE ON public.bills
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bill_members_updated_at BEFORE UPDATE ON public.bill_members
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_bill_items_updated_at BEFORE UPDATE ON public.bill_items
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- STORAGE BUCKET for Payment Proofs
-- ============================================

-- Create storage bucket for payment proofs (run this in Supabase Dashboard > Storage)
-- INSERT INTO storage.buckets (id, name, public) 
-- VALUES ('payment-proofs', 'payment-proofs', false);

-- Storage policies (run after bucket creation)
/*
CREATE POLICY "Users can upload their own payment proofs"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'payment-proofs' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

CREATE POLICY "Users can view payment proofs of their bills"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'payment-proofs' AND
  EXISTS (
    SELECT 1 FROM public.bill_members
    WHERE bill_members.proof_url = storage.objects.name
    AND EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND (bills.created_by = auth.uid() OR 
           EXISTS (SELECT 1 FROM public.bill_members bm2 
                   WHERE bm2.bill_id = bills.id 
                   AND bm2.user_id = auth.uid()))
    )
  )
);
*/

-- ============================================
-- SAMPLE DATA (Optional - for testing)
-- ============================================

/*
-- Insert sample bill
INSERT INTO public.bills (created_by, title, tax_percent, service_percent)
VALUES (
  auth.uid(), -- Your user ID
  'Dinner at Resto ABC',
  10, -- 10% tax
  5   -- 5% service
);
*/

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check if all tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('bills', 'bill_members', 'bill_items', 'item_assignments')
ORDER BY table_name;

-- Check enum types
SELECT typname FROM pg_type WHERE typname IN ('bill_status', 'payment_status');

COMMIT;
