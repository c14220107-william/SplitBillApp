-- ============================================
-- FIX RLS POLICIES - Remove Infinite Recursion
-- ============================================

-- Drop ALL existing policies for all tables
DO $$ 
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT policyname, tablename 
        FROM pg_policies 
        WHERE schemaname = 'public' 
        AND tablename IN ('bills', 'bill_members', 'bill_items', 'item_assignments')
    ) LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', r.policyname, r.tablename);
    END LOOP;
END $$;

-- ============================================
-- OPTION 1: DISABLE RLS (For Development/Testing)
-- Uncomment lines below if you want to disable RLS temporarily
-- ============================================

-- ALTER TABLE public.bills DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.bill_members DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.bill_items DISABLE ROW LEVEL SECURITY;
-- ALTER TABLE public.item_assignments DISABLE ROW LEVEL SECURITY;

-- ============================================
-- OPTION 2: SIMPLIFIED POLICIES (Recommended)
-- ============================================

-- BILLS POLICIES - No cross-table checks to avoid recursion
CREATE POLICY "Users can view their own bills"
  ON public.bills FOR SELECT
  USING (auth.uid() = created_by);

CREATE POLICY "Users can create their own bills"
  ON public.bills FOR INSERT
  WITH CHECK (auth.uid() = created_by);

CREATE POLICY "Only bill creator can update their bills"
  ON public.bills FOR UPDATE
  USING (auth.uid() = created_by);

CREATE POLICY "Only bill creator can delete their bills"
  ON public.bills FOR DELETE
  USING (auth.uid() = created_by);

-- BILL MEMBERS POLICIES (SIMPLIFIED - No recursion)
CREATE POLICY "Bill creator can view all members"
  ON public.bill_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Members can view themselves"
  ON public.bill_members FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Bill creator can add members"
  ON public.bill_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Bill creator can update members"
  ON public.bill_members FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Members can update their own payment info"
  ON public.bill_members FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Bill creator can delete members"
  ON public.bill_members FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_members.bill_id
      AND bills.created_by = auth.uid()
    )
  );

-- BILL ITEMS POLICIES
CREATE POLICY "Bill creator can view items"
  ON public.bill_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_items.bill_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Bill members can view items"
  ON public.bill_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_members
      WHERE bill_members.bill_id = bill_items.bill_id
      AND bill_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Only bill creator can insert items"
  ON public.bill_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_items.bill_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Only bill creator can update items"
  ON public.bill_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_items.bill_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Only bill creator can delete items"
  ON public.bill_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.bills
      WHERE bills.id = bill_items.bill_id
      AND bills.created_by = auth.uid()
    )
  );

-- ITEM ASSIGNMENTS POLICIES
CREATE POLICY "Bill creator can view assignments"
  ON public.item_assignments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_items
      JOIN public.bills ON bills.id = bill_items.bill_id
      WHERE bill_items.id = item_assignments.item_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Assigned users can view their assignments"
  ON public.item_assignments FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Only bill creator can insert assignments"
  ON public.item_assignments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bill_items
      JOIN public.bills ON bills.id = bill_items.bill_id
      WHERE bill_items.id = item_assignments.item_id
      AND bills.created_by = auth.uid()
    )
  );

CREATE POLICY "Only bill creator can delete assignments"
  ON public.item_assignments FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_items
      JOIN public.bills ON bills.id = bill_items.bill_id
      WHERE bill_items.id = item_assignments.item_id
      AND bills.created_by = auth.uid()
    )
  );

-- ============================================
-- VERIFY POLICIES
-- ============================================

-- Check all policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('bills', 'bill_members', 'bill_items', 'item_assignments')
ORDER BY tablename, policyname;

COMMIT;
