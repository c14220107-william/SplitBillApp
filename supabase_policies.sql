-- ==============================================
-- SPLITBILLERS - ROW LEVEL SECURITY POLICIES
-- ==============================================
-- File ini berisi semua RLS policies untuk database Supabase
-- Jalankan script ini di SQL Editor Supabase setelah membuat tabel

-- 1. Enable RLS pada semua tabel
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_assignments ENABLE ROW LEVEL SECURITY;

-- ==============================================
-- POLICIES UNTUK TABEL: profiles
-- ==============================================

-- Semua user bisa membaca semua profiles (untuk invite user)
CREATE POLICY "Profiles are viewable by everyone"
  ON public.profiles FOR SELECT
  USING (true);

-- User hanya bisa insert profile mereka sendiri
CREATE POLICY "Users can insert their own profile"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- User hanya bisa update profile mereka sendiri
CREATE POLICY "Users can update their own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ==============================================
-- POLICIES UNTUK TABEL: bills
-- ==============================================

-- User bisa membaca bill yang mereka buat ATAU yang mereka diundang
CREATE POLICY "Users can view bills they created or are invited to"
  ON public.bills FOR SELECT
  USING (
    created_by = auth.uid() 
    OR EXISTS (
      SELECT 1 FROM public.bill_members 
      WHERE bill_id = bills.id AND user_id = auth.uid()
    )
  );

-- User bisa membuat bill baru
CREATE POLICY "Users can create bills"
  ON public.bills FOR INSERT
  WITH CHECK (created_by = auth.uid());

-- Hanya creator yang bisa update bill mereka
CREATE POLICY "Only creator can update their bills"
  ON public.bills FOR UPDATE
  USING (created_by = auth.uid())
  WITH CHECK (created_by = auth.uid());

-- Hanya creator yang bisa delete bill mereka
CREATE POLICY "Only creator can delete their bills"
  ON public.bills FOR DELETE
  USING (created_by = auth.uid());

-- ==============================================
-- POLICIES UNTUK TABEL: bill_members
-- ==============================================

-- User bisa melihat members dari bill yang mereka akses
CREATE POLICY "Users can view members of accessible bills"
  ON public.bill_members FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_members.bill_id 
      AND (
        bills.created_by = auth.uid() 
        OR EXISTS (
          SELECT 1 FROM public.bill_members bm 
          WHERE bm.bill_id = bills.id AND bm.user_id = auth.uid()
        )
      )
    )
  );

-- Hanya creator bill yang bisa menambah members
CREATE POLICY "Only bill creator can add members"
  ON public.bill_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_members.bill_id 
      AND bills.created_by = auth.uid()
    )
  );

-- Member bisa update status pembayaran mereka sendiri (upload proof)
-- Creator bisa update semua members
CREATE POLICY "Members can update their own payment status"
  ON public.bill_members FOR UPDATE
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_members.bill_id 
      AND bills.created_by = auth.uid()
    )
  )
  WITH CHECK (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_members.bill_id 
      AND bills.created_by = auth.uid()
    )
  );

-- Hanya creator yang bisa delete members
CREATE POLICY "Only bill creator can delete members"
  ON public.bill_members FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_members.bill_id 
      AND bills.created_by = auth.uid()
    )
  );

-- ==============================================
-- POLICIES UNTUK TABEL: bill_items
-- ==============================================

-- User bisa melihat items dari bill yang mereka akses
CREATE POLICY "Users can view items of accessible bills"
  ON public.bill_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_items.bill_id 
      AND (
        bills.created_by = auth.uid() 
        OR EXISTS (
          SELECT 1 FROM public.bill_members 
          WHERE bill_members.bill_id = bills.id 
          AND bill_members.user_id = auth.uid()
        )
      )
    )
  );

-- Hanya creator bill yang bisa menambah items
CREATE POLICY "Only bill creator can add items"
  ON public.bill_items FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_items.bill_id 
      AND bills.created_by = auth.uid()
    )
  );

-- Hanya creator bill yang bisa update items
CREATE POLICY "Only bill creator can update items"
  ON public.bill_items FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_items.bill_id 
      AND bills.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_items.bill_id 
      AND bills.created_by = auth.uid()
    )
  );

-- Hanya creator bill yang bisa delete items
CREATE POLICY "Only bill creator can delete items"
  ON public.bill_items FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.bills 
      WHERE bills.id = bill_items.bill_id 
      AND bills.created_by = auth.uid()
    )
  );

-- ==============================================
-- POLICIES UNTUK TABEL: item_assignments
-- ==============================================

-- User bisa melihat assignments dari bill yang mereka akses
CREATE POLICY "Users can view assignments of accessible bills"
  ON public.item_assignments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_items bi
      JOIN public.bills b ON b.id = bi.bill_id
      WHERE bi.id = item_assignments.item_id 
      AND (
        b.created_by = auth.uid() 
        OR EXISTS (
          SELECT 1 FROM public.bill_members 
          WHERE bill_members.bill_id = b.id 
          AND bill_members.user_id = auth.uid()
        )
      )
    )
  );

-- Hanya creator bill yang bisa assign items ke users
CREATE POLICY "Only bill creator can assign items"
  ON public.item_assignments FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bill_items bi
      JOIN public.bills b ON b.id = bi.bill_id
      WHERE bi.id = item_assignments.item_id 
      AND b.created_by = auth.uid()
    )
  );

-- Hanya creator bill yang bisa update assignments
CREATE POLICY "Only bill creator can update assignments"
  ON public.item_assignments FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_items bi
      JOIN public.bills b ON b.id = bi.bill_id
      WHERE bi.id = item_assignments.item_id 
      AND b.created_by = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bill_items bi
      JOIN public.bills b ON b.id = bi.bill_id
      WHERE bi.id = item_assignments.item_id 
      AND b.created_by = auth.uid()
    )
  );

-- Hanya creator bill yang bisa delete assignments
CREATE POLICY "Only bill creator can delete assignments"
  ON public.item_assignments FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.bill_items bi
      JOIN public.bills b ON b.id = bi.bill_id
      WHERE bi.id = item_assignments.item_id 
      AND b.created_by = auth.uid()
    )
  );

-- ==============================================
-- STORAGE POLICIES (untuk upload foto bukti bayar & avatar)
-- ==============================================

-- Buat bucket di Supabase Storage: 'avatars' dan 'payment_proofs'
-- Jalankan policies berikut di SQL Editor:

-- BUCKET: avatars
-- Semua user bisa upload avatar mereka sendiri
CREATE POLICY "Users can upload their own avatar"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Semua user bisa update avatar mereka sendiri
CREATE POLICY "Users can update their own avatar"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Semua user bisa delete avatar mereka sendiri
CREATE POLICY "Users can delete their own avatar"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'avatars' 
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- Semua orang bisa melihat avatar (public read)
CREATE POLICY "Avatars are publicly accessible"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- BUCKET: payment_proofs
-- User bisa upload bukti bayar untuk bill yang mereka participate
CREATE POLICY "Users can upload payment proof"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'payment_proofs' 
    AND auth.uid() IS NOT NULL
  );

-- User bisa update bukti bayar mereka sendiri
CREATE POLICY "Users can update their payment proof"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'payment_proofs' 
    AND auth.uid() IS NOT NULL
  );

-- User yang terlibat bisa melihat bukti bayar
CREATE POLICY "Bill participants can view payment proofs"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'payment_proofs' 
    AND auth.uid() IS NOT NULL
  );

-- ==============================================
-- FUNGSI HELPER (Optional - untuk trigger otomatis)
-- ==============================================

-- Function untuk auto-create profile saat user register
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, updated_at)
  VALUES (
    new.id,
    new.email,
    new.raw_user_meta_data->>'full_name',
    now()
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger untuk auto-create profile
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================
-- SELESAI
-- ==============================================
-- Jangan lupa:
-- 1. Buat bucket 'avatars' dan 'payment_proofs' di Supabase Storage
-- 2. Set bucket 'avatars' sebagai public
-- 3. Set bucket 'payment_proofs' sebagai private
