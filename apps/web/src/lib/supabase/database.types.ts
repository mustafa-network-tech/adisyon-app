// Hand-written to match supabase/migrations/*.sql (no live project to run
// `supabase gen types` against yet). Keep in sync when the schema changes;
// regenerate with the Supabase CLI once a real project exists:
//   supabase gen types typescript --project-id <ref> > src/lib/supabase/database.types.ts

export type SubscriptionStatus =
  | "TRIAL"
  | "ACTIVE"
  | "GRACE_PERIOD"
  | "EXPIRED"
  | "SUSPENDED"
  | "CANCELLED";
export type GooglePlayPurchaseState =
  | "PENDING"
  | "ACTIVE"
  | "GRACE_PERIOD"
  | "ON_HOLD"
  | "CANCELLED"
  | "EXPIRED"
  | "REVOKED";
export type ApplicationStatus = "PENDING" | "APPROVED" | "REJECTED";
export type MembershipRole = "BUSINESS_ADMIN" | "CASHIER" | "WAITER" | "KITCHEN";
export type TableStatus = "AVAILABLE" | "OCCUPIED" | "CHECK_REQUESTED";
export type OrderStatus = "OPEN" | "CLOSED" | "CANCELLED";
export type OrderItemStatus = "NEW" | "PREPARING" | "READY" | "SERVED" | "VOID";
export type PaymentMethod = "CASH" | "CARD" | "OTHER";
export type PaymentStatus = "COMPLETED" | "VOID";
export type SupportRequestType = "TECHNICAL_SUPPORT" | "FEATURE_REQUEST" | "OTHER";
export type SupportRequestStatus = "OPEN" | "IN_PROGRESS" | "RESOLVED" | "CLOSED";
export type CustomSoftwareRequestStatus = "PENDING" | "IN_REVIEW" | "CLOSED";

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          full_name: string | null;
          phone: string | null;
          email: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["profiles"]["Row"]> & { id: string };
        Update: Partial<Database["public"]["Tables"]["profiles"]["Row"]>;
        Relationships: [];
      };
      platform_admins: {
        Row: { user_id: string; created_at: string };
        Insert: { user_id: string; created_at?: string };
        Update: Partial<{ user_id: string; created_at: string }>;
        Relationships: [];
      };
      plans: {
        Row: {
          id: string;
          name: string;
          monthly_price: number;
          yearly_price: number;
          yearly_discount: number;
          max_tables: number | null;
          max_waiters: number | null;
          max_users: number | null;
          max_areas: number | null;
          max_branches: number | null;
          qr_menu_enabled: boolean;
          reporting_level: string;
          feature_flags: Record<string, unknown>;
          google_play_product_id: string | null;
          google_play_monthly_base_plan_id: string | null;
          google_play_yearly_base_plan_id: string | null;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["plans"]["Row"]> & { name: string };
        Update: Partial<Database["public"]["Tables"]["plans"]["Row"]>;
        Relationships: [];
      };
      businesses: {
        Row: {
          id: string;
          name: string;
          business_type: string | null;
          city: string | null;
          address: string | null;
          phone: string | null;
          email: string | null;
          logo_url: string | null;
          plan_id: string | null;
          subscription_status: SubscriptionStatus;
          trial_started_at: string;
          trial_ends_at: string;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["businesses"]["Row"]> & { name: string };
        Update: Partial<Database["public"]["Tables"]["businesses"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "businesses_plan_id_fkey";
            columns: ["plan_id"];
            isOneToOne: false;
            referencedRelation: "plans";
            referencedColumns: ["id"];
          }
        ];
      };
      business_memberships: {
        Row: {
          id: string;
          user_id: string;
          business_id: string;
          role: MembershipRole;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["business_memberships"]["Row"]> & {
          user_id: string;
          business_id: string;
          role: MembershipRole;
        };
        Update: Partial<Database["public"]["Tables"]["business_memberships"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "business_memberships_user_id_fkey";
            columns: ["user_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "business_memberships_business_id_fkey";
            columns: ["business_id"];
            isOneToOne: false;
            referencedRelation: "businesses";
            referencedColumns: ["id"];
          }
        ];
      };
      business_applications: {
        Row: {
          id: string;
          business_name: string;
          business_type: string | null;
          contact_name: string;
          phone: string;
          email: string;
          city: string | null;
          address: string | null;
          estimated_tables: number | null;
          description: string | null;
          consents_accepted: boolean;
          status: ApplicationStatus;
          reviewed_by: string | null;
          reviewed_at: string | null;
          rejection_reason: string | null;
          resulting_business_id: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["business_applications"]["Row"]> & {
          business_name: string;
          contact_name: string;
          phone: string;
          email: string;
          consents_accepted: boolean;
        };
        Update: Partial<Database["public"]["Tables"]["business_applications"]["Row"]>;
        Relationships: [];
      };
      subscriptions: {
        Row: {
          id: string;
          business_id: string;
          plan_id: string;
          status: SubscriptionStatus;
          started_at: string;
          ends_at: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["subscriptions"]["Row"]> & {
          business_id: string;
          plan_id: string;
          status: SubscriptionStatus;
        };
        Update: Partial<Database["public"]["Tables"]["subscriptions"]["Row"]>;
        Relationships: [];
      };
      areas: {
        Row: {
          id: string;
          business_id: string;
          name: string;
          sort_order: number;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["areas"]["Row"]> & {
          business_id: string;
          name: string;
        };
        Update: Partial<Database["public"]["Tables"]["areas"]["Row"]>;
        Relationships: [];
      };
      restaurant_tables: {
        Row: {
          id: string;
          business_id: string;
          area_id: string;
          name: string;
          status: TableStatus;
          sort_order: number;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["restaurant_tables"]["Row"]> & {
          business_id: string;
          area_id: string;
          name: string;
        };
        Update: Partial<Database["public"]["Tables"]["restaurant_tables"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "restaurant_tables_area_id_fkey";
            columns: ["area_id"];
            isOneToOne: false;
            referencedRelation: "areas";
            referencedColumns: ["id"];
          }
        ];
      };
      categories: {
        Row: {
          id: string;
          business_id: string;
          name: string;
          sort_order: number;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["categories"]["Row"]> & {
          business_id: string;
          name: string;
        };
        Update: Partial<Database["public"]["Tables"]["categories"]["Row"]>;
        Relationships: [];
      };
      products: {
        Row: {
          id: string;
          business_id: string;
          category_id: string | null;
          name: string;
          description: string | null;
          price: number;
          image_url: string | null;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["products"]["Row"]> & {
          business_id: string;
          name: string;
          price: number;
        };
        Update: Partial<Database["public"]["Tables"]["products"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "products_category_id_fkey";
            columns: ["category_id"];
            isOneToOne: false;
            referencedRelation: "categories";
            referencedColumns: ["id"];
          }
        ];
      };
      orders: {
        Row: {
          id: string;
          business_id: string;
          table_id: string;
          status: OrderStatus;
          opened_by: string;
          opened_at: string;
          closed_at: string | null;
          check_requested: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["orders"]["Row"]> & {
          business_id: string;
          table_id: string;
          opened_by: string;
        };
        Update: Partial<Database["public"]["Tables"]["orders"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "orders_table_id_fkey";
            columns: ["table_id"];
            isOneToOne: false;
            referencedRelation: "restaurant_tables";
            referencedColumns: ["id"];
          }
        ];
      };
      order_items: {
        Row: {
          id: string;
          order_id: string;
          business_id: string;
          product_id: string;
          product_name_snapshot: string;
          unit_price_snapshot: number;
          quantity: number;
          note: string | null;
          status: OrderItemStatus;
          voided_by: string | null;
          voided_at: string | null;
          void_reason: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["order_items"]["Row"]> & {
          order_id: string;
          product_id: string;
          quantity: number;
        };
        Update: Partial<Database["public"]["Tables"]["order_items"]["Row"]>;
        Relationships: [];
      };
      payments: {
        Row: {
          id: string;
          order_id: string;
          business_id: string;
          method: PaymentMethod;
          amount: number;
          status: PaymentStatus;
          received_by: string;
          voided_by: string | null;
          voided_at: string | null;
          void_reason: string | null;
          // Idempotency key (20260922000028) -- optional, unique per
          // order when present. See payment-panel.tsx.
          client_request_id: string | null;
          created_at: string;
        };
        // received_by is intentionally not required here: the
        // check_payment_order_business trigger (20260922000020) always
        // overwrites it from auth.uid() server-side, the same way
        // business_id is derived rather than client-supplied.
        Insert: Partial<Database["public"]["Tables"]["payments"]["Row"]> & {
          order_id: string;
          method: PaymentMethod;
          amount: number;
        };
        Update: Partial<Database["public"]["Tables"]["payments"]["Row"]>;
        Relationships: [];
      };
      support_requests: {
        Row: {
          id: string;
          business_id: string;
          requester_id: string;
          type: SupportRequestType;
          subject: string;
          description: string;
          status: SupportRequestStatus;
          created_at: string;
          updated_at: string;
        };
        // requester_id is intentionally not required here: a trigger
        // (20260922000024) always overwrites it from auth.uid().
        Insert: Partial<Database["public"]["Tables"]["support_requests"]["Row"]> & {
          business_id: string;
          type: SupportRequestType;
          subject: string;
          description: string;
        };
        Update: Partial<Database["public"]["Tables"]["support_requests"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "support_requests_business_id_fkey";
            columns: ["business_id"];
            isOneToOne: false;
            referencedRelation: "businesses";
            referencedColumns: ["id"];
          }
        ];
      };
      custom_software_requests: {
        Row: {
          id: string;
          business_id: string | null;
          requester_name: string;
          phone: string;
          email: string;
          branch_count: number | null;
          need: string;
          description: string | null;
          status: CustomSoftwareRequestStatus;
          created_at: string;
          updated_at: string;
        };
        Insert: Partial<Database["public"]["Tables"]["custom_software_requests"]["Row"]> & {
          requester_name: string;
          phone: string;
          email: string;
          need: string;
        };
        Update: Partial<Database["public"]["Tables"]["custom_software_requests"]["Row"]>;
        Relationships: [
          {
            foreignKeyName: "custom_software_requests_business_id_fkey";
            columns: ["business_id"];
            isOneToOne: false;
            referencedRelation: "businesses";
            referencedColumns: ["id"];
          }
        ];
      };
      audit_logs: {
        Row: {
          id: string;
          actor_id: string | null;
          business_id: string | null;
          action: string;
          entity: string;
          entity_id: string | null;
          metadata: Record<string, unknown>;
          created_at: string;
        };
        Insert: never;
        Update: never;
        Relationships: [
          {
            foreignKeyName: "audit_logs_actor_id_fkey";
            columns: ["actor_id"];
            isOneToOne: false;
            referencedRelation: "profiles";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "audit_logs_business_id_fkey";
            columns: ["business_id"];
            isOneToOne: false;
            referencedRelation: "businesses";
            referencedColumns: ["id"];
          }
        ];
      };
      google_play_purchases: {
        Row: {
          id: string;
          business_id: string;
          plan_id: string | null;
          product_id: string;
          base_plan_id: string | null;
          // purchase_token exists on the row but is only ever readable by
          // a platform admin (google_play_purchases_select_platform_admin)
          // -- business-facing code must use get_own_business_subscription
          // instead, which never returns it.
          purchase_token: string;
          order_id: string | null;
          purchase_state: GooglePlayPurchaseState;
          auto_renewing: boolean;
          start_time: string | null;
          expiry_time: string | null;
          last_verified_at: string | null;
          raw_verification_response: Record<string, unknown>;
          created_at: string;
          updated_at: string;
        };
        // No client Insert/Update -- see
        // 20260922000026_google_play_subscriptions.sql: writes only
        // happen via apply_google_play_verification_result, which isn't
        // granted to `authenticated` at all yet.
        Insert: never;
        Update: never;
        Relationships: [
          {
            foreignKeyName: "google_play_purchases_business_id_fkey";
            columns: ["business_id"];
            isOneToOne: false;
            referencedRelation: "businesses";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "google_play_purchases_plan_id_fkey";
            columns: ["plan_id"];
            isOneToOne: false;
            referencedRelation: "plans";
            referencedColumns: ["id"];
          }
        ];
      };
    };
    Views: Record<string, never>;
    Functions: {
      is_platform_admin: { Args: Record<string, never>; Returns: boolean };
      has_business_role: { Args: { p_business_id: string; p_roles: string[] }; Returns: boolean };
      is_business_member: { Args: { p_business_id: string }; Returns: boolean };
      // log_audit_event still exists in the database but its EXECUTE
      // grant to `authenticated` was revoked (20260922000027) -- it's
      // now only called internally by SECURITY DEFINER triggers. Kept
      // here only as documentation of the underlying signature, not
      // because client code may call it.
      log_audit_event: {
        Args: {
          p_business_id: string | null;
          p_action: string;
          p_entity: string;
          p_entity_id: string | null;
          p_metadata?: Record<string, unknown>;
        };
        Returns: string;
      };
      create_own_business: {
        Args: {
          p_name: string;
          p_business_type?: string | null;
          p_city?: string | null;
          p_address?: string | null;
          p_phone?: string | null;
          p_email?: string | null;
        };
        Returns: string;
      };
      get_own_business_subscription: {
        Args: { p_business_id: string };
        Returns: {
          product_id: string;
          base_plan_id: string | null;
          purchase_state: GooglePlayPurchaseState;
          auto_renewing: boolean;
          start_time: string | null;
          expiry_time: string | null;
          last_verified_at: string | null;
        }[];
      };
      get_revenue_summary: {
        Args: { p_business_id: string; p_start: string; p_end: string };
        Returns: {
          total_revenue: number;
          cash_total: number;
          card_total: number;
          other_total: number;
          order_count: number;
          average_order: number;
        }[];
      };
      get_top_products: {
        Args: { p_business_id: string; p_start: string; p_end: string; p_limit?: number };
        Returns: { product_name: string; total_quantity: number; total_revenue: number }[];
      };
      get_qr_menu_business: {
        Args: { p_business_id: string };
        Returns: { name: string; logo_url: string | null; business_type: string | null; city: string | null }[];
      };
      get_qr_menu_items: {
        Args: { p_business_id: string };
        Returns: {
          category_id: string;
          category_name: string;
          category_sort_order: number;
          product_id: string | null;
          product_name: string | null;
          product_description: string | null;
          product_price: number | null;
          product_image_url: string | null;
        }[];
      };
    };
  };
}
