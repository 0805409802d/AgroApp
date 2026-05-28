-- ============================================================
-- Gestor de Archivos y Base de Datos (Folders, Documents)
-- ============================================================

-- 1. Tabla de Carpetas (Folders)
CREATE TABLE IF NOT EXISTS folders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES folders(id) ON DELETE CASCADE, -- NULL si es raíz
  name text NOT NULL,
  content_type text NOT NULL DEFAULT 'none', -- 'none', 'documents', 'contacts'
  created_at timestamptz DEFAULT now()
);

ALTER TABLE folders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner_all" ON folders;
CREATE POLICY "owner_all" ON folders
  FOR ALL
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

-- 2. Tabla de Documentos
CREATE TABLE IF NOT EXISTS documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  folder_id uuid NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
  name text NOT NULL,
  file_url text NOT NULL,
  file_type text, -- pdf, docx, etc.
  size_bytes bigint DEFAULT 0,
  created_at timestamptz DEFAULT now()
);

ALTER TABLE documents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner_all" ON documents;
CREATE POLICY "owner_all" ON documents
  FOR ALL
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

-- 3. Actualización a tabla de Farmers (Contactos / Personas)
-- Añadimos las columnas necesarias de forma segura
DO $$ 
BEGIN 
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='farmers' AND column_name='folder_id') THEN
    ALTER TABLE farmers ADD COLUMN folder_id uuid REFERENCES folders(id) ON DELETE SET NULL;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='farmers' AND column_name='last_name') THEN
    ALTER TABLE farmers ADD COLUMN last_name text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='farmers' AND column_name='email') THEN
    ALTER TABLE farmers ADD COLUMN email text;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='farmers' AND column_name='description') THEN
    ALTER TABLE farmers ADD COLUMN description text;
  END IF;
END $$;

-- 4. Creación del Storage Bucket
INSERT INTO storage.buckets (id, name, public) 
VALUES ('business_documents', 'business_documents', false) 
ON CONFLICT (id) DO NOTHING;

-- RLS para Storage Objects
-- El formato de guardado será: {business_id}/{folder_id}/{filename}
-- Así podemos limitar el acceso asegurándonos que el owner tenga acceso a su carpeta business_id.
DROP POLICY IF EXISTS "owner_access" ON storage.objects;
CREATE POLICY "owner_access" ON storage.objects
  FOR ALL
  USING (
    bucket_id = 'business_documents' AND
    (storage.foldername(name))[1] IN (
      SELECT id::text FROM businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    bucket_id = 'business_documents' AND
    (storage.foldername(name))[1] IN (
      SELECT id::text FROM businesses WHERE user_id = auth.uid()
    )
  );
