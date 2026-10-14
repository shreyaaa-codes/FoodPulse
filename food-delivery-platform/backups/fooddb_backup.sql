--
-- PostgreSQL database dump
--

\restrict ut4OYg5ksihPE74gUZ4DwVQTTaUYqaIxpbLN3iiXi4uNBp0lisJNZ3Jw5dHBCG5

-- Dumped from database version 16.15 (Debian 16.15-1.pgdg13+2)
-- Dumped by pg_dump version 16.15 (Debian 16.15-1.pgdg13+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dim_customer; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_customer (
    customer_key integer NOT NULL,
    customer_id text NOT NULL,
    name text,
    city text
);


ALTER TABLE public.dim_customer OWNER TO postgres;

--
-- Name: dim_customer_customer_key_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dim_customer_customer_key_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dim_customer_customer_key_seq OWNER TO postgres;

--
-- Name: dim_customer_customer_key_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dim_customer_customer_key_seq OWNED BY public.dim_customer.customer_key;


--
-- Name: dim_restaurant; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_restaurant (
    restaurant_key integer NOT NULL,
    restaurant_id text NOT NULL,
    name text,
    cuisine text,
    city text
);


ALTER TABLE public.dim_restaurant OWNER TO postgres;

--
-- Name: dim_restaurant_restaurant_key_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.dim_restaurant_restaurant_key_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.dim_restaurant_restaurant_key_seq OWNER TO postgres;

--
-- Name: dim_restaurant_restaurant_key_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.dim_restaurant_restaurant_key_seq OWNED BY public.dim_restaurant.restaurant_key;


--
-- Name: dim_time; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.dim_time (
    time_key integer NOT NULL,
    full_date date,
    day integer,
    month integer,
    month_name text,
    quarter integer,
    year integer,
    weekday text,
    is_weekend boolean
);


ALTER TABLE public.dim_time OWNER TO postgres;

--
-- Name: fact_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.fact_orders (
    order_id text NOT NULL,
    customer_key integer,
    restaurant_key integer,
    time_key integer,
    order_hour integer,
    item_name text,
    quantity integer,
    unit_price numeric(10,2),
    total_amount numeric(10,2),
    status text,
    payment_method text
);


ALTER TABLE public.fact_orders OWNER TO postgres;

--
-- Name: rejected_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.rejected_orders (
    id integer NOT NULL,
    order_id text,
    payload jsonb,
    reason text,
    rejected_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.rejected_orders OWNER TO postgres;

--
-- Name: rejected_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.rejected_orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rejected_orders_id_seq OWNER TO postgres;

--
-- Name: rejected_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.rejected_orders_id_seq OWNED BY public.rejected_orders.id;


--
-- Name: stg_orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.stg_orders (
    id integer NOT NULL,
    order_id text,
    payload jsonb NOT NULL,
    received_at timestamp without time zone DEFAULT now(),
    processed boolean DEFAULT false
);


ALTER TABLE public.stg_orders OWNER TO postgres;

--
-- Name: stg_orders_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.stg_orders_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.stg_orders_id_seq OWNER TO postgres;

--
-- Name: stg_orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.stg_orders_id_seq OWNED BY public.stg_orders.id;


--
-- Name: vw_daily_revenue; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_daily_revenue AS
 SELECT t.full_date,
    count(*) AS orders,
    sum(f.total_amount) AS revenue
   FROM (public.fact_orders f
     JOIN public.dim_time t USING (time_key))
  WHERE (f.status = 'DELIVERED'::text)
  GROUP BY t.full_date;


ALTER VIEW public.vw_daily_revenue OWNER TO postgres;

--
-- Name: vw_monthly_revenue; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_monthly_revenue AS
 SELECT make_date(t.year, t.month, 1) AS month_start,
    sum(f.total_amount) AS revenue
   FROM (public.fact_orders f
     JOIN public.dim_time t USING (time_key))
  WHERE (f.status = 'DELIVERED'::text)
  GROUP BY t.year, t.month;


ALTER VIEW public.vw_monthly_revenue OWNER TO postgres;

--
-- Name: vw_monthly_growth; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_monthly_growth AS
 SELECT month_start,
    revenue,
    lag(revenue) OVER (ORDER BY month_start) AS prev_revenue,
    round(((100.0 * (revenue - lag(revenue) OVER (ORDER BY month_start))) / NULLIF(lag(revenue) OVER (ORDER BY month_start), (0)::numeric)), 2) AS growth_pct
   FROM public.vw_monthly_revenue;


ALTER VIEW public.vw_monthly_growth OWNER TO postgres;

--
-- Name: vw_orders_by_hour; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_orders_by_hour AS
 SELECT order_hour,
    count(*) AS orders
   FROM public.fact_orders
  GROUP BY order_hour;


ALTER VIEW public.vw_orders_by_hour OWNER TO postgres;

--
-- Name: vw_repeat_customer_pct; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_repeat_customer_pct AS
 WITH c AS (
         SELECT fact_orders.customer_key,
            count(*) AS n
           FROM public.fact_orders
          GROUP BY fact_orders.customer_key
        )
 SELECT count(*) AS total_customers,
    count(*) FILTER (WHERE (n > 1)) AS repeat_customers,
    round(((100.0 * (count(*) FILTER (WHERE (n > 1)))::numeric) / (NULLIF(count(*), 0))::numeric), 2) AS repeat_pct
   FROM c;


ALTER VIEW public.vw_repeat_customer_pct OWNER TO postgres;

--
-- Name: vw_top_restaurants; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.vw_top_restaurants AS
 SELECT r.name AS restaurant,
    r.city,
    r.cuisine,
    count(*) AS orders,
    sum(f.total_amount) AS revenue
   FROM (public.fact_orders f
     JOIN public.dim_restaurant r USING (restaurant_key))
  WHERE (f.status = 'DELIVERED'::text)
  GROUP BY r.name, r.city, r.cuisine;


ALTER VIEW public.vw_top_restaurants OWNER TO postgres;

--
-- Name: dim_customer customer_key; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_customer ALTER COLUMN customer_key SET DEFAULT nextval('public.dim_customer_customer_key_seq'::regclass);


--
-- Name: dim_restaurant restaurant_key; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_restaurant ALTER COLUMN restaurant_key SET DEFAULT nextval('public.dim_restaurant_restaurant_key_seq'::regclass);


--
-- Name: rejected_orders id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rejected_orders ALTER COLUMN id SET DEFAULT nextval('public.rejected_orders_id_seq'::regclass);


--
-- Name: stg_orders id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stg_orders ALTER COLUMN id SET DEFAULT nextval('public.stg_orders_id_seq'::regclass);


--
-- Data for Name: dim_customer; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dim_customer (customer_key, customer_id, name, city) FROM stdin;
1	CUST101	Aarav Sharma	Mumbai
9	C0183	Arjun Desai	Thane
13	C0391	Aarav Patil	Pune
97	C0127	Neha Iyer	Thane
593	C0097	Aarav Nair	Thane
605	C0011	Anjali Kulkarni	Mumbai
242	C0065	Vikram Joshi	Mumbai
6	C0302	Rohan Nair	Pune
44	C0204	Anjali Joshi	Thane
416	C0353	Sneha Nair	Mumbai
411	C0156	Vikram Mehta	Mumbai
39	C0322	Rohan Patil	Mumbai
598	C0201	Arjun Joshi	Thane
434	C0056	Vikram Singh	Pune
63	C0198	Pooja Patil	Mumbai
64	C0230	Kabir Singh	Thane
118	C0222	Vikram Sharma	Thane
69	C0170	Kabir Patil	Mumbai
136	C0269	Pooja Khan	Pune
75	C0202	Rohan Kulkarni	Thane
82	C0334	Rohan Mehta	Thane
678	C0094	Aarav Nair	Thane
683	C0285	Anjali Patil	Pune
684	C0074	Priya Kulkarni	Thane
30	C0367	Riya Desai	Pune
67	C0220	Neha Singh	Pune
569	C0397	Pooja Iyer	Pune
117	C0280	Sahil Joshi	Mumbai
110	C0149	Riya Nair	Pune
74	C0276	Arjun Singh	Mumbai
50	C0032	Kabir Khan	Pune
32	C0079	Aarav Patil	Thane
707	C0106	Riya Joshi	Pune
421	C0263	Arjun Joshi	Thane
132	C0020	Sahil Joshi	Mumbai
267	C0279	Aarav Singh	Mumbai
332	C0310	Anjali Kulkarni	Mumbai
525	C0372	Neha Khan	Thane
722	C0182	Sneha Khan	Thane
441	C0022	Priya Nair	Mumbai
36	C0266	Neha Patil	Mumbai
129	C0363	Rohan Desai	Pune
195	C0352	Riya Mehta	Thane
15	C0136	Sahil Sharma	Pune
149	C0036	Priya Kulkarni	Thane
269	C0385	Vikram Patil	Pune
158	C0059	Pooja Singh	Mumbai
168	C0122	Anjali Sharma	Pune
161	C0001	Pooja Kulkarni	Thane
124	C0270	Arjun Singh	Pune
71	C0218	Neha Patil	Thane
169	C0078	Kabir Kulkarni	Pune
740	C0295	Kabir Singh	Thane
41	C0008	Neha Iyer	Pune
66	C0062	Anjali Kulkarni	Thane
453	C0037	Anjali Iyer	Pune
121	C0274	Aarav Singh	Mumbai
188	C0223	Arjun Sharma	Pune
139	C0312	Vikram Sharma	Thane
193	C0369	Pooja Desai	Pune
394	C0211	Arjun Mehta	Pune
206	C0214	Pooja Joshi	Mumbai
25	C0185	Rohan Mehta	Mumbai
227	C0184	Priya Patil	Pune
468	C0336	Riya Iyer	Thane
116	C0086	Sahil Mehta	Thane
100	C0342	Priya Iyer	Pune
451	C0147	Sneha Desai	Thane
790	C0254	Sahil Singh	Pune
250	C0019	Kabir Khan	Mumbai
792	C0237	Priya Desai	Thane
43	C0057	Vikram Iyer	Thane
175	C0077	Riya Kulkarni	Mumbai
148	C0256	Sahil Singh	Pune
511	C0305	Aarav Nair	Thane
534	C0091	Neha Sharma	Pune
799	C0131	Sahil Iyer	Thane
20	C0299	Vikram Desai	Mumbai
275	C0113	Anjali Singh	Mumbai
809	C0083	Rohan Iyer	Pune
62	C0235	Anjali Desai	Mumbai
95	C0055	Vikram Mehta	Mumbai
157	C0313	Pooja Joshi	Mumbai
287	C0063	Arjun Patil	Mumbai
351	C0278	Sahil Kulkarni	Thane
187	C0286	Riya Nair	Mumbai
392	C0273	Kabir Singh	Thane
325	C0166	Neha Patil	Thane
109	C0029	Sahil Desai	Mumbai
290	C0118	Riya Patil	Thane
236	C0386	Vikram Khan	Thane
400	C0335	Kabir Nair	Mumbai
310	C0255	Arjun Kulkarni	Mumbai
284	C0301	Anjali Sharma	Mumbai
379	C0308	Pooja Joshi	Pune
145	C0234	Riya Nair	Pune
288	C0192	Aarav Patil	Mumbai
326	C0169	Rohan Patil	Thane
21	C0210	Anjali Joshi	Mumbai
378	C0003	Neha Mehta	Thane
344	C0143	Sahil Mehta	Thane
347	C0394	Neha Joshi	Pune
348	C0199	Priya Nair	Thane
353	C0172	Arjun Sharma	Pune
402	C0133	Sneha Patil	Pune
355	C0289	Pooja Iyer	Thane
4	C0229	Arjun Iyer	Mumbai
246	C0146	Riya Singh	Thane
361	C0194	Rohan Sharma	Mumbai
406	C0152	Anjali Sharma	Mumbai
296	C0323	Priya Kulkarni	Mumbai
98	C0049	Aarav Kulkarni	Mumbai
292	C0126	Sneha Nair	Mumbai
276	C0134	Sneha Khan	Mumbai
103	C0026	Kabir Mehta	Mumbai
173	C0148	Aarav Mehta	Pune
388	C0018	Riya Sharma	Mumbai
487	C0364	Arjun Iyer	Pune
390	C0355	Sahil Joshi	Thane
404	C0331	Rohan Mehta	Mumbai
16	C0167	Aarav Iyer	Thane
407	C0232	Priya Iyer	Mumbai
205	C0316	Rohan Desai	Thane
803	C0111	Priya Kulkarni	Thane
210	C0098	Anjali Sharma	Mumbai
829	C0116	Sneha Desai	Thane
218	C0242	Priya Singh	Mumbai
661	C0241	Sneha Mehta	Pune
200	C0357	Arjun Joshi	Thane
417	C0038	Anjali Patil	Pune
424	C0193	Riya Joshi	Pune
199	C0054	Vikram Desai	Pune
53	C0378	Aarav Sharma	Pune
133	C0349	Aarav Sharma	Mumbai
214	C0319	Sahil Joshi	Thane
367	C0005	Rohan Kulkarni	Mumbai
47	C0371	Sneha Mehta	Mumbai
438	C0356	Arjun Khan	Thane
342	C0268	Arjun Patil	Mumbai
166	C0375	Vikram Patil	Mumbai
260	C0368	Riya Desai	Mumbai
262	C0052	Kabir Iyer	Pune
483	C0207	Kabir Singh	Mumbai
249	C0400	Aarav Kulkarni	Thane
485	C0396	Kabir Desai	Pune
488	C0179	Vikram Singh	Mumbai
135	C0315	Vikram Singh	Thane
327	C0217	Anjali Kulkarni	Pune
465	C0247	Kabir Khan	Thane
514	C0112	Pooja Desai	Thane
224	C0370	Sahil Khan	Thane
282	C0362	Anjali Nair	Thane
522	C0129	Riya Patil	Mumbai
111	C0259	Riya Joshi	Pune
24	C0294	Riya Mehta	Pune
387	C0045	Vikram Singh	Mumbai
533	C0027	Priya Singh	Pune
172	C0249	Kabir Khan	Pune
450	C0161	Sneha Patil	Thane
286	C0387	Priya Joshi	Pune
545	C0195	Sahil Mehta	Mumbai
52	C0226	Sahil Iyer	Mumbai
549	C0064	Anjali Mehta	Pune
65	C0186	Neha Singh	Pune
551	C0399	Sneha Patil	Pune
152	C0100	Sneha Joshi	Pune
559	C0110	Kabir Desai	Thane
557	C0271	Kabir Nair	Mumbai
140	C0012	Riya Singh	Pune
448	C0291	Kabir Desai	Thane
8	C0175	Kabir Sharma	Pune
156	C0277	Priya Nair	Thane
447	C0035	Arjun Patil	Thane
11	C0128	Pooja Desai	Thane
561	C0014	Aarav Sharma	Pune
70	C0120	Priya Mehta	Thane
587	C0138	Aarav Sharma	Pune
79	C0099	Vikram Joshi	Thane
254	C0132	Sahil Mehta	Thane
194	C0350	Vikram Desai	Mumbai
856	C0130	Sahil Nair	Pune
341	C0039	Aarav Iyer	Mumbai
203	C0212	Aarav Iyer	Thane
180	C0084	Riya Singh	Thane
77	C0144	Neha Sharma	Pune
869	C0081	Neha Mehta	Thane
871	C0330	Vikram Singh	Thane
874	C0040	Sneha Kulkarni	Mumbai
130	C0337	Kabir Mehta	Thane
27	C0140	Sneha Mehta	Mumbai
56	C0265	Vikram Sharma	Thane
654	C0171	Sneha Singh	Thane
295	C0137	Neha Iyer	Thane
880	C0324	Kabir Singh	Thane
2	C0293	Anjali Patil	Mumbai
289	C0298	Kabir Mehta	Mumbai
884	C0382	Rohan Iyer	Thane
362	C0178	Kabir Sharma	Thane
165	C0125	Sneha Desai	Thane
313	C0252	Kabir Sharma	Mumbai
85	C0292	Pooja Khan	Thane
891	C0358	Anjali Khan	Thane
197	C0281	Neha Desai	Thane
147	C0102	Sahil Khan	Pune
55	C0208	Neha Singh	Pune
107	C0025	Sneha Patil	Thane
711	C0010	Priya Singh	Pune
29	C0360	Sahil Singh	Mumbai
778	C0304	Sahil Iyer	Thane
904	C0373	Anjali Nair	Mumbai
7	C0002	Rohan Singh	Pune
505	C0251	Riya Nair	Pune
908	C0346	Priya Iyer	Mumbai
49	C0258	Arjun Singh	Mumbai
895	C0089	Arjun Kulkarni	Thane
445	C0046	Rohan Kulkarni	Thane
72	C0188	Riya Iyer	Mumbai
232	C0135	Neha Sharma	Pune
34	C0287	Aarav Kulkarni	Mumbai
221	C0224	Neha Joshi	Mumbai
22	C0105	Sahil Singh	Pune
37	C0160	Aarav Kulkarni	Thane
243	C0344	Rohan Patil	Thane
258	C0248	Vikram Joshi	Mumbai
588	C0309	Priya Kulkarni	Pune
562	C0016	Vikram Singh	Thane
219	C0303	Sneha Iyer	Thane
35	C0354	Rohan Mehta	Thane
934	C0216	Neha Khan	Pune
415	C0320	Priya Desai	Pune
17	C0284	Neha Desai	Mumbai
153	C0209	Priya Iyer	Mumbai
710	C0115	Sahil Iyer	Thane
253	C0388	Vikram Patil	Thane
298	C0180	Priya Sharma	Pune
265	C0321	Pooja Nair	Thane
45	C0145	Aarav Desai	Pune
608	C0176	Kabir Kulkarni	Thane
635	C0379	Priya Singh	Pune
179	C0092	Arjun Kulkarni	Mumbai
662	C0236	Arjun Desai	Mumbai
843	C0215	Pooja Kulkarni	Thane
171	C0339	Anjali Nair	Mumbai
19	C0153	Vikram Patil	Thane
119	C0107	Aarav Singh	Thane
329	C0158	Riya Sharma	Pune
967	C0051	Priya Joshi	Thane
622	C0042	Rohan Desai	Thane
170	C0392	Pooja Singh	Thane
93	C0066	Kabir Patil	Pune
128	C0124	Vikram Desai	Thane
151	C0073	Kabir Desai	Mumbai
970	C0328	Vikram Joshi	Pune
146	C0282	Priya Singh	Pune
108	C0275	Rohan Nair	Pune
754	C0307	Sneha Khan	Thane
114	C0332	Riya Iyer	Thane
779	C0109	Sneha Iyer	Thane
18	C0244	Arjun Iyer	Pune
580	C0311	Arjun Mehta	Mumbai
33	C0041	Priya Iyer	Pune
430	C0283	Neha Joshi	Thane
12	C0240	Anjali Singh	Mumbai
196	C0231	Aarav Joshi	Thane
680	C0047	Vikram Nair	Mumbai
162	C0053	Rohan Desai	Thane
320	C0006	Sahil Sharma	Pune
101	C0090	Aarav Singh	Mumbai
144	C0103	Priya Khan	Mumbai
184	C0023	Kabir Mehta	Mumbai
994	C0050	Sahil Singh	Mumbai
92	C0380	Pooja Iyer	Thane
283	C0238	Kabir Iyer	Pune
486	C0221	Arjun Nair	Pune
38	C0338	Neha Joshi	Thane
60	C0253	Sahil Khan	Thane
720	C0181	Rohan Sharma	Pune
46	C0067	Anjali Patil	Thane
408	C0123	Arjun Desai	Thane
369	C0261	Rohan Joshi	Pune
26	C0393	Priya Joshi	Pune
352	C0117	Pooja Nair	Thane
497	C0233	Priya Desai	Mumbai
42	C0228	Neha Iyer	Thane
474	C0206	Sneha Nair	Pune
76	C0245	Aarav Nair	Thane
31	C0031	Kabir Kulkarni	Mumbai
371	C0028	Vikram Kulkarni	Thane
701	C0340	Sahil Sharma	Mumbai
398	C0377	Aarav Desai	Thane
951	C0239	Sneha Desai	Pune
527	C0351	Sahil Sharma	Pune
126	C0389	Pooja Singh	Thane
174	C0070	Kabir Sharma	Mumbai
80	C0007	Riya Khan	Thane
515	C0196	Vikram Joshi	Thane
216	C0191	Priya Iyer	Pune
494	C0314	Priya Desai	Thane
752	C0398	Riya Singh	Thane
646	C0173	Anjali Joshi	Thane
23	C0155	Rohan Mehta	Pune
99	C0030	Sneha Iyer	Thane
10	C0219	Arjun Nair	Pune
233	C0034	Neha Mehta	Thane
1051	C0033	Sneha Joshi	Pune
204	C0333	Kabir Joshi	Thane
777	C0327	Priya Joshi	Mumbai
1056	C0343	Rohan Sharma	Mumbai
198	C0290	Vikram Desai	Mumbai
636	C0257	Kabir Singh	Thane
480	C0341	Kabir Joshi	Thane
676	C0297	Sneha Singh	Pune
160	C0088	Neha Singh	Mumbai
88	C0141	Priya Joshi	Thane
5	C0203	Sneha Patil	Pune
235	C0044	Aarav Khan	Thane
1066	C0108	Kabir Nair	Pune
770	C0163	Pooja Singh	Mumbai
104	C0061	Anjali Kulkarni	Thane
183	C0009	Pooja Singh	Mumbai
234	C0359	Priya Kulkarni	Pune
840	C0246	Riya Khan	Pune
425	C0300	Sahil Sharma	Pune
504	C0101	Kabir Iyer	Mumbai
317	C0345	Kabir Iyer	Pune
1076	C0390	Vikram Kulkarni	Thane
14	C0096	Sneha Patil	Thane
456	C0095	Riya Nair	Thane
54	C0348	Rohan Khan	Thane
127	C0162	Vikram Sharma	Mumbai
1081	C0157	Rohan Khan	Mumbai
229	C0325	Arjun Kulkarni	Thane
90	C0213	Rohan Desai	Thane
443	C0139	Priya Kulkarni	Thane
578	C0104	Vikram Iyer	Mumbai
1029	C0024	Sneha Nair	Mumbai
535	C0365	Rohan Singh	Mumbai
225	C0075	Neha Joshi	Pune
48	C0288	Anjali Nair	Mumbai
738	C0190	Rohan Singh	Thane
354	C0121	Arjun Joshi	Thane
340	C0072	Arjun Desai	Pune
356	C0381	Sahil Khan	Thane
755	C0151	Pooja Sharma	Thane
816	C0165	Sneha Desai	Thane
231	C0318	Vikram Sharma	Pune
1099	C0087	Rohan Kulkarni	Thane
215	C0159	Sneha Sharma	Thane
420	C0114	Kabir Kulkarni	Thane
255	C0076	Sahil Kulkarni	Pune
613	C0225	Priya Patil	Mumbai
59	C0384	Vikram Patil	Mumbai
120	C0347	Priya Joshi	Thane
182	C0017	Aarav Sharma	Mumbai
753	C0174	Riya Kulkarni	Mumbai
531	C0082	Sahil Desai	Thane
57	C0267	Aarav Khan	Thane
467	C0058	Vikram Patil	Mumbai
1111	C0150	Kabir Mehta	Pune
850	C0021	Sahil Singh	Mumbai
532	C0200	Riya Iyer	Pune
409	C0004	Priya Sharma	Pune
122	C0154	Rohan Khan	Thane
181	C0366	Sahil Iyer	Thane
89	C0376	Arjun Sharma	Pune
811	C0043	Sahil Iyer	Thane
360	C0227	Priya Kulkarni	Pune
102	C0329	Kabir Kulkarni	Mumbai
134	C0197	Sahil Singh	Pune
966	C0085	Sneha Kulkarni	Mumbai
346	C0015	Kabir Patil	Pune
1125	C0306	Riya Joshi	Pune
28	C0068	Neha Patil	Pune
3	C0187	Arjun Kulkarni	Thane
264	C0205	Pooja Nair	Thane
112	C0060	Riya Iyer	Pune
\.


--
-- Data for Name: dim_restaurant; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dim_restaurant (restaurant_key, restaurant_id, name, cuisine, city) FROM stdin;
1	REST201	Spice Garden	Indian	Mumbai
10	R002	Dragon Wok	Chinese	Mumbai
9	R007	Tandoori Nights	North Indian	Thane
3	R001	Spice Garden	North Indian	Mumbai
4	R003	Pizza Palace	Italian	Mumbai
19	R004	Dosa Corner	South Indian	Pune
6	R006	Burger Barn	Fast Food	Pune
2	R008	Sushi Zen	Japanese	Thane
17	R005	Biryani House	Hyderabadi	Pune
\.


--
-- Data for Name: dim_time; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.dim_time (time_key, full_date, day, month, month_name, quarter, year, weekday, is_weekend) FROM stdin;
20261010	2026-10-10	10	10	October	4	2026	Saturday	t
20260730	2026-07-30	30	7	July	3	2026	Thursday	f
20260724	2026-07-24	24	7	July	3	2026	Friday	f
20260825	2026-08-25	25	8	August	3	2026	Tuesday	f
20260829	2026-08-29	29	8	August	3	2026	Saturday	t
20260913	2026-09-13	13	9	September	3	2026	Sunday	t
20260927	2026-09-27	27	9	September	3	2026	Sunday	t
20260822	2026-08-22	22	8	August	3	2026	Saturday	t
20260805	2026-08-05	5	8	August	3	2026	Wednesday	f
20260923	2026-09-23	23	9	September	3	2026	Wednesday	f
20260830	2026-08-30	30	8	August	3	2026	Sunday	t
20260907	2026-09-07	7	9	September	3	2026	Monday	f
20260926	2026-09-26	26	9	September	3	2026	Saturday	t
20260924	2026-09-24	24	9	September	3	2026	Thursday	f
20260915	2026-09-15	15	9	September	3	2026	Tuesday	f
20260819	2026-08-19	19	8	August	3	2026	Wednesday	f
20260826	2026-08-26	26	8	August	3	2026	Wednesday	f
20260929	2026-09-29	29	9	September	3	2026	Tuesday	f
20260818	2026-08-18	18	8	August	3	2026	Tuesday	f
20260928	2026-09-28	28	9	September	3	2026	Monday	f
20260906	2026-09-06	6	9	September	3	2026	Sunday	t
20260804	2026-08-04	4	8	August	3	2026	Tuesday	f
20260905	2026-09-05	5	9	September	3	2026	Saturday	t
20261003	2026-10-03	3	10	October	4	2026	Saturday	t
20260725	2026-07-25	25	7	July	3	2026	Saturday	t
20260720	2026-07-20	20	7	July	3	2026	Monday	f
20260801	2026-08-01	1	8	August	3	2026	Saturday	t
20260714	2026-07-14	14	7	July	3	2026	Tuesday	f
20260807	2026-08-07	7	8	August	3	2026	Friday	f
20261002	2026-10-02	2	10	October	4	2026	Friday	f
20260813	2026-08-13	13	8	August	3	2026	Thursday	f
20260914	2026-09-14	14	9	September	3	2026	Monday	f
20261008	2026-10-08	8	10	October	4	2026	Thursday	f
20261005	2026-10-05	5	10	October	4	2026	Monday	f
20261007	2026-10-07	7	10	October	4	2026	Wednesday	f
20260723	2026-07-23	23	7	July	3	2026	Thursday	f
20260827	2026-08-27	27	8	August	3	2026	Thursday	f
20260903	2026-09-03	3	9	September	3	2026	Thursday	f
20260727	2026-07-27	27	7	July	3	2026	Monday	f
20260922	2026-09-22	22	9	September	3	2026	Tuesday	f
20261001	2026-10-01	1	10	October	4	2026	Thursday	f
20260828	2026-08-28	28	8	August	3	2026	Friday	f
20260731	2026-07-31	31	7	July	3	2026	Friday	f
20260918	2026-09-18	18	9	September	3	2026	Friday	f
20260910	2026-09-10	10	9	September	3	2026	Thursday	f
20260722	2026-07-22	22	7	July	3	2026	Wednesday	f
20260909	2026-09-09	9	9	September	3	2026	Wednesday	f
20260806	2026-08-06	6	8	August	3	2026	Thursday	f
20260726	2026-07-26	26	7	July	3	2026	Sunday	t
20260809	2026-08-09	9	8	August	3	2026	Sunday	t
20260930	2026-09-30	30	9	September	3	2026	Wednesday	f
20260820	2026-08-20	20	8	August	3	2026	Thursday	f
20260817	2026-08-17	17	8	August	3	2026	Monday	f
20261006	2026-10-06	6	10	October	4	2026	Tuesday	f
20260803	2026-08-03	3	8	August	3	2026	Monday	f
20260729	2026-07-29	29	7	July	3	2026	Wednesday	f
20260823	2026-08-23	23	8	August	3	2026	Sunday	t
20260802	2026-08-02	2	8	August	3	2026	Sunday	t
20260808	2026-08-08	8	8	August	3	2026	Saturday	t
20260728	2026-07-28	28	7	July	3	2026	Tuesday	f
20260713	2026-07-13	13	7	July	3	2026	Monday	f
20260916	2026-09-16	16	9	September	3	2026	Wednesday	f
20260919	2026-09-19	19	9	September	3	2026	Saturday	t
20260911	2026-09-11	11	9	September	3	2026	Friday	f
20260717	2026-07-17	17	7	July	3	2026	Friday	f
20260719	2026-07-19	19	7	July	3	2026	Sunday	t
20260814	2026-08-14	14	8	August	3	2026	Friday	f
20260811	2026-08-11	11	8	August	3	2026	Tuesday	f
20260815	2026-08-15	15	8	August	3	2026	Saturday	t
20260718	2026-07-18	18	7	July	3	2026	Saturday	t
20261009	2026-10-09	9	10	October	4	2026	Friday	f
20260816	2026-08-16	16	8	August	3	2026	Sunday	t
20261004	2026-10-04	4	10	October	4	2026	Sunday	t
20260821	2026-08-21	21	8	August	3	2026	Friday	f
20260925	2026-09-25	25	9	September	3	2026	Friday	f
20260716	2026-07-16	16	7	July	3	2026	Thursday	f
20260921	2026-09-21	21	9	September	3	2026	Monday	f
20260810	2026-08-10	10	8	August	3	2026	Monday	f
20260831	2026-08-31	31	8	August	3	2026	Monday	f
20260904	2026-09-04	4	9	September	3	2026	Friday	f
20260721	2026-07-21	21	7	July	3	2026	Tuesday	f
20260812	2026-08-12	12	8	August	3	2026	Wednesday	f
20260908	2026-09-08	8	9	September	3	2026	Tuesday	f
20260902	2026-09-02	2	9	September	3	2026	Wednesday	f
20260901	2026-09-01	1	9	September	3	2026	Tuesday	f
20260920	2026-09-20	20	9	September	3	2026	Sunday	t
20260715	2026-07-15	15	7	July	3	2026	Wednesday	f
20260912	2026-09-12	12	9	September	3	2026	Saturday	t
20260917	2026-09-17	17	9	September	3	2026	Thursday	f
20260824	2026-08-24	24	8	August	3	2026	Monday	f
20261014	2026-10-14	14	10	October	4	2026	Wednesday	f
20261011	2026-10-11	11	10	October	4	2026	Sunday	t
20261013	2026-10-13	13	10	October	4	2026	Tuesday	f
20261012	2026-10-12	12	10	October	4	2026	Monday	f
\.


--
-- Data for Name: fact_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.fact_orders (order_id, customer_key, restaurant_key, time_key, order_hour, item_name, quantity, unit_price, total_amount, status, payment_method) FROM stdin;
ORD1001	1	1	20261010	18	Paneer Biryani	2	250.00	500.00	DELIVERED	UPI
ORD628949BB6C	2	2	20260730	13	Ramen Bowl	4	380.00	1520.00	CANCELLED	CARD
ORD3E385A31DA	3	3	20260724	13	Butter Chicken	1	320.00	320.00	DELIVERED	UPI
ORD8BFF85479A	4	4	20260825	21	Margherita Pizza	2	299.00	598.00	DELIVERED	UPI
ORD890ED0C5F5	5	3	20260829	21	Butter Chicken	1	320.00	320.00	DELIVERED	UPI
ORD18BBA7A73E	6	6	20260913	17	Chicken Wrap	1	140.00	140.00	DELIVERED	COD
ORD0511B47E15	7	4	20260927	13	Garlic Bread	3	120.00	360.00	DELIVERED	CARD
ORDF675D1E916	8	4	20260822	21	Pasta Alfredo	2	280.00	560.00	DELIVERED	UPI
ORD4AFFC2D989	9	9	20260927	20	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORDCAD27B6CB8	10	10	20260805	21	Hakka Noodles	4	190.00	760.00	DELIVERED	CARD
ORD7E2F63DD7D	11	3	20260724	13	Butter Chicken	2	320.00	640.00	DELIVERED	CARD
ORDAE98857C28	12	3	20260923	21	Butter Chicken	3	320.00	960.00	DELIVERED	COD
ORD84D4DCAC4D	13	6	20260923	17	Cheese Burger	1	150.00	150.00	DELIVERED	CARD
ORD422F351342	14	10	20260830	22	Fried Rice	3	180.00	540.00	DELIVERED	CARD
ORDDCE7538742	15	10	20260907	16	Manchurian	3	210.00	630.00	DELIVERED	COD
ORD75191839D7	16	9	20260926	13	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORDF0D752CCF5	17	17	20260924	21	Raita	2	40.00	80.00	DELIVERED	UPI
ORD49413A5F8E	18	9	20260915	20	Paneer Butter Masala	2	250.00	500.00	DELIVERED	COD
ORD88816BD4A6	19	19	20260819	16	Masala Dosa	2	110.00	220.00	DELIVERED	CARD
ORD0146B8278E	20	4	20260826	16	Garlic Bread	3	120.00	360.00	DELIVERED	CARD
ORD474BD33A10	21	19	20260929	12	Masala Dosa	4	110.00	440.00	DELIVERED	COD
ORD2DB4AF01A7	22	4	20260819	14	Margherita Pizza	3	299.00	897.00	DELIVERED	COD
ORDAAFEEDABC2	23	2	20260818	21	Ramen Bowl	4	380.00	1520.00	DELIVERED	UPI
ORDA2DEB4B5D2	24	19	20260928	20	Masala Dosa	4	110.00	440.00	CANCELLED	CARD
ORDEDD03CB8F9	25	10	20260826	19	Hakka Noodles	4	190.00	760.00	DELIVERED	UPI
ORDFF2EA29F97	26	17	20260819	17	Veg Biryani	2	220.00	440.00	PLACED	UPI
ORD4D9A997E65	27	19	20260906	20	Filter Coffee	2	40.00	80.00	DELIVERED	CARD
ORDEF880B684F	28	2	20260929	13	Veg Sushi Roll	4	350.00	1400.00	PLACED	UPI
ORDD8F19E4294	29	19	20260804	12	Idli Sambar	2	80.00	160.00	DELIVERED	UPI
ORDB37F3C4BDC	30	19	20260905	13	Idli Sambar	2	80.00	160.00	DELIVERED	CARD
ORD5953D28E15	31	9	20261003	13	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORDF252C5B271	32	10	20260725	19	Hakka Noodles	1	190.00	190.00	DELIVERED	COD
ORD1B180251EB	33	6	20260720	16	Cheese Burger	3	150.00	450.00	DELIVERED	UPI
ORD36D2EFB69C	34	10	20260724	12	Manchurian	1	210.00	210.00	DELIVERED	UPI
ORD922CA88B15	35	3	20260907	20	Butter Chicken	2	320.00	640.00	CANCELLED	UPI
ORDDE9CBDA759	36	3	20260915	9	Paneer Tikka	4	260.00	1040.00	DELIVERED	CARD
ORD393169E53A	37	6	20260801	8	French Fries	4	90.00	360.00	DELIVERED	UPI
ORD0BD81F6879	38	3	20260714	19	Paneer Tikka	2	260.00	520.00	DELIVERED	UPI
ORD241B383085	39	10	20260929	20	Hakka Noodles	2	190.00	380.00	DELIVERED	UPI
ORDBDD75971C5	25	4	20260807	8	Garlic Bread	2	120.00	240.00	DELIVERED	COD
ORDF1E3A81964	41	6	20261002	9	French Fries	2	90.00	180.00	DELIVERED	CARD
ORD9AF839FE8D	42	9	20260813	13	Butter Naan	1	55.00	55.00	CANCELLED	UPI
ORDFDB677F9EE	43	19	20260914	14	Masala Dosa	3	110.00	330.00	DELIVERED	UPI
ORD9DC5DD4361	44	2	20260801	9	Ramen Bowl	4	380.00	1520.00	DELIVERED	COD
ORD1DF83FC535	45	2	20261008	8	Ramen Bowl	1	380.00	380.00	DELIVERED	COD
ORDBA3D0066EC	46	4	20261005	22	Margherita Pizza	4	299.00	1196.00	DELIVERED	UPI
ORD058106691B	47	10	20261007	16	Manchurian	4	210.00	840.00	DELIVERED	UPI
ORD42E3C80F06	48	10	20260723	13	Fried Rice	4	180.00	720.00	DELIVERED	UPI
ORD26EC95F59D	49	3	20260827	12	Garlic Naan	4	60.00	240.00	DELIVERED	CARD
ORD4AB02ACF88	50	9	20260903	13	Butter Naan	2	55.00	110.00	DELIVERED	COD
ORD3EABD56B9C	8	4	20260727	21	Margherita Pizza	4	299.00	1196.00	DELIVERED	UPI
ORD643269EAD3	52	3	20260818	21	Garlic Naan	4	60.00	240.00	DELIVERED	UPI
ORDE6B14A6F5F	53	6	20260801	21	Cheese Burger	4	150.00	600.00	DELIVERED	COD
ORD2FFC24961E	54	17	20260922	9	Raita	4	40.00	160.00	DELIVERED	CARD
ORDDC70788C73	55	19	20260725	13	Filter Coffee	3	40.00	120.00	DELIVERED	UPI
ORD19D11CF0DE	56	10	20261001	9	Fried Rice	3	180.00	540.00	CANCELLED	UPI
ORDCB81CB9933	57	3	20260828	12	Paneer Tikka	4	260.00	1040.00	PLACED	UPI
ORD8F2B20F0BE	45	2	20260826	20	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORD3F80A58837	59	2	20260731	21	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	COD
ORD402577B739	60	17	20260918	20	Chicken Biryani	4	280.00	1120.00	DELIVERED	COD
ORDE6A6D92F63	49	4	20260826	21	Margherita Pizza	3	299.00	897.00	DELIVERED	COD
ORD7E7B52B8BA	62	4	20260910	13	Pasta Alfredo	2	280.00	560.00	DELIVERED	UPI
ORD9EA78815E3	63	4	20260926	19	Garlic Bread	1	120.00	120.00	DELIVERED	CARD
ORD4E1227217B	64	9	20260722	16	Tandoori Chicken	3	340.00	1020.00	PLACED	CARD
ORD3E2D22883A	65	19	20260909	12	Filter Coffee	1	40.00	40.00	DELIVERED	UPI
ORDD2FBCEA5FD	66	10	20260922	19	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORDA18A0C36AD	67	17	20260826	19	Raita	3	40.00	120.00	CANCELLED	UPI
ORD9CC36838FB	18	2	20260806	17	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	CARD
ORD246E2CF9E5	69	10	20260726	17	Manchurian	3	210.00	630.00	DELIVERED	UPI
ORDF737CF2BC5	70	19	20260809	13	Filter Coffee	1	40.00	40.00	DELIVERED	UPI
ORDA791065C18	71	2	20260930	20	Veg Sushi Roll	2	350.00	700.00	DELIVERED	UPI
ORD60738FE4ED	72	4	20261005	21	Margherita Pizza	2	299.00	598.00	DELIVERED	UPI
ORDCD31DE5438	41	19	20260822	12	Idli Sambar	2	80.00	160.00	DELIVERED	UPI
ORD2839214D6C	74	10	20260820	13	Hakka Noodles	3	190.00	570.00	DELIVERED	UPI
ORD0E396D20E2	75	2	20260817	9	Veg Sushi Roll	3	350.00	1050.00	PLACED	UPI
ORDB33D0D8596	76	10	20260726	16	Fried Rice	4	180.00	720.00	DELIVERED	UPI
ORD803CC43C87	77	3	20260929	16	Butter Chicken	3	320.00	960.00	DELIVERED	COD
ORD4C75998ABE	3	10	20260906	20	Hakka Noodles	1	190.00	190.00	DELIVERED	UPI
ORDCD1263BED6	79	9	20261006	22	Paneer Butter Masala	3	250.00	750.00	CANCELLED	UPI
ORD549EFDB258	80	17	20260817	9	Raita	1	40.00	40.00	DELIVERED	UPI
ORDE10B2F5BA4	57	10	20260803	20	Hakka Noodles	2	190.00	380.00	DELIVERED	COD
ORD3E700C079A	82	9	20260820	19	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORD5361B96C16	24	17	20260918	20	Raita	1	40.00	40.00	DELIVERED	CARD
ORD047F76BE52	25	3	20260819	17	Garlic Naan	1	60.00	60.00	DELIVERED	UPI
ORD0C7F2E7B52	85	3	20260914	13	Garlic Naan	2	60.00	120.00	DELIVERED	COD
ORDCC909D938E	59	2	20261003	17	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	COD
ORDBFFA1B30D5	49	3	20260729	21	Dal Makhani	4	220.00	880.00	DELIVERED	UPI
ORDCF6A4BBA59	88	2	20260915	13	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORD2D158D0897	89	2	20260714	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	COD
ORD11CD2B3D63	90	3	20260823	13	Butter Chicken	1	320.00	320.00	DELIVERED	UPI
ORD322E2D81E4	67	19	20260828	21	Idli Sambar	3	80.00	240.00	DELIVERED	CARD
ORD4C32D97772	92	10	20260914	12	Hakka Noodles	3	190.00	570.00	DELIVERED	COD
ORD8D01102625	93	19	20261007	20	Idli Sambar	4	80.00	320.00	DELIVERED	CARD
ORDC98FF7F2F5	3	3	20260926	8	Paneer Tikka	1	260.00	260.00	DELIVERED	UPI
ORD3C9C14DA70	95	3	20261005	12	Dal Makhani	4	220.00	880.00	DELIVERED	CARD
ORD516CD09F9E	50	2	20260927	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORD6CB27DB895	97	19	20260818	20	Masala Dosa	4	110.00	440.00	DELIVERED	UPI
ORDC1AFF7C8B9	98	2	20260802	17	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORDCBF187EB2D	99	6	20260808	13	Chicken Wrap	3	140.00	420.00	DELIVERED	UPI
ORDD52946728F	100	2	20260929	20	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORDEA0800B0A0	101	9	20260728	13	Paneer Butter Masala	1	250.00	250.00	DELIVERED	COD
ORDAD17206EA9	102	9	20261003	21	Paneer Butter Masala	1	250.00	250.00	DELIVERED	UPI
ORD3C60D091DA	103	19	20260713	8	Masala Dosa	2	110.00	220.00	DELIVERED	COD
ORDB594096243	104	2	20260916	8	Veg Sushi Roll	2	350.00	700.00	PLACED	CARD
ORD3114DBF769	67	6	20260923	8	French Fries	2	90.00	180.00	CANCELLED	UPI
ORDFC8DCCC968	28	9	20260919	20	Butter Naan	1	55.00	55.00	DELIVERED	CARD
ORD62B93883BC	107	10	20260910	19	Fried Rice	3	180.00	540.00	DELIVERED	COD
ORD5D18798612	108	10	20260825	21	Manchurian	1	210.00	210.00	PLACED	UPI
ORDCDD43E70D1	109	10	20260825	22	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORDAC7EE254D3	110	19	20260826	12	Filter Coffee	3	40.00	120.00	DELIVERED	UPI
ORD64BC71C963	111	19	20260911	17	Filter Coffee	1	40.00	40.00	DELIVERED	UPI
ORDE68593BADB	112	9	20260926	22	Butter Naan	2	55.00	110.00	DELIVERED	COD
ORD6345A88B42	74	3	20261003	21	Dal Makhani	4	220.00	880.00	DELIVERED	UPI
ORD8E0AE99591	114	3	20261006	13	Paneer Tikka	2	260.00	520.00	DELIVERED	COD
ORD0C1C8263D7	88	9	20260724	19	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORD9E7388C4AF	116	2	20260924	16	Ramen Bowl	1	380.00	380.00	DELIVERED	COD
ORDEC0C3AF880	117	10	20260717	13	Manchurian	3	210.00	630.00	DELIVERED	CARD
ORDE8963745DA	118	6	20260927	19	Chicken Wrap	4	140.00	560.00	DELIVERED	UPI
ORD658CAB7A30	119	9	20260727	22	Paneer Butter Masala	3	250.00	750.00	DELIVERED	CARD
ORDA117074C7B	120	2	20260924	16	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	CARD
ORD5CA2252421	121	2	20260808	21	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORD889CF33344	122	17	20260719	22	Raita	3	40.00	120.00	DELIVERED	CARD
ORD7564D5F250	19	6	20261007	13	French Fries	3	90.00	270.00	DELIVERED	COD
ORDC09E5F36E2	124	19	20260803	20	Idli Sambar	2	80.00	160.00	CANCELLED	UPI
ORD69322BDFEB	6	19	20260814	9	Idli Sambar	4	80.00	320.00	DELIVERED	COD
ORDF0250DD658	126	6	20260804	20	Cheese Burger	1	150.00	150.00	DELIVERED	UPI
ORDFA8737193D	127	17	20260928	21	Veg Biryani	1	220.00	220.00	DELIVERED	UPI
ORDA13A496B3B	128	2	20260811	17	Miso Soup	3	150.00	450.00	DELIVERED	COD
ORD3B1F37F32C	129	17	20260918	8	Raita	2	40.00	80.00	DELIVERED	CARD
ORD5911F9A2C7	130	10	20260717	19	Hakka Noodles	1	190.00	190.00	DELIVERED	UPI
ORD0BC4EF93E4	29	19	20260905	13	Filter Coffee	4	40.00	160.00	DELIVERED	COD
ORD5FE37322CF	132	3	20260730	8	Paneer Tikka	3	260.00	780.00	DELIVERED	COD
ORDB9CB06E4A1	133	10	20260815	19	Fried Rice	2	180.00	360.00	CANCELLED	COD
ORDE98AAAAA6D	134	3	20261008	19	Paneer Tikka	2	260.00	520.00	DELIVERED	COD
ORD024AF702B2	135	2	20260808	19	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD38A6FC9F78	136	17	20260819	17	Raita	3	40.00	120.00	DELIVERED	CARD
ORD4E721583E0	60	6	20260915	16	French Fries	1	90.00	90.00	DELIVERED	UPI
ORD1F9EBE4F5F	38	10	20260926	17	Fried Rice	4	180.00	720.00	DELIVERED	UPI
ORDEB2A5D1020	139	2	20261008	22	Veg Sushi Roll	1	350.00	350.00	CANCELLED	UPI
ORDC72CE025E9	140	9	20260718	14	Tandoori Chicken	1	340.00	340.00	CANCELLED	CARD
ORD5CBC9C2BE3	36	10	20260827	8	Manchurian	4	210.00	840.00	PLACED	UPI
ORD117A49CEFB	120	9	20260914	16	Butter Naan	2	55.00	110.00	CANCELLED	UPI
ORDEF9D59D3D0	129	19	20260724	8	Idli Sambar	3	80.00	240.00	DELIVERED	COD
ORD988F57DF06	144	2	20260907	14	Ramen Bowl	1	380.00	380.00	DELIVERED	UPI
ORD078AECC7E6	145	19	20260906	14	Filter Coffee	1	40.00	40.00	DELIVERED	COD
ORD67343DED6D	146	4	20260927	14	Pasta Alfredo	1	280.00	280.00	DELIVERED	UPI
ORD9B0D1AF746	147	2	20260913	22	Ramen Bowl	4	380.00	1520.00	DELIVERED	COD
ORD56EF84E893	148	10	20260728	21	Hakka Noodles	1	190.00	190.00	DELIVERED	UPI
ORD648841ADF5	149	4	20260808	20	Pasta Alfredo	1	280.00	280.00	DELIVERED	CARD
ORD7CED31517A	52	3	20260719	20	Butter Chicken	1	320.00	320.00	PLACED	CARD
ORD7854474E4F	151	19	20260928	17	Filter Coffee	3	40.00	120.00	DELIVERED	CARD
ORDECEB49511A	152	6	20260802	16	Chicken Wrap	2	140.00	280.00	DELIVERED	COD
ORD9169DE2917	153	19	20261009	21	Masala Dosa	3	110.00	330.00	DELIVERED	COD
ORDDDEEA32A12	76	4	20260905	19	Garlic Bread	2	120.00	240.00	DELIVERED	UPI
ORDAB22D474EC	27	19	20260802	21	Idli Sambar	2	80.00	160.00	DELIVERED	UPI
ORD14C22D90C9	156	9	20260820	20	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD8959FDBEF6	157	2	20260724	12	Ramen Bowl	4	380.00	1520.00	DELIVERED	UPI
ORD4E988B9E75	158	4	20260927	16	Pasta Alfredo	2	280.00	560.00	CANCELLED	UPI
ORD4ABA4B7449	15	3	20260829	20	Paneer Tikka	3	260.00	780.00	DELIVERED	CARD
ORDFCC09BF293	160	10	20260918	20	Hakka Noodles	2	190.00	380.00	DELIVERED	UPI
ORDE382119614	161	2	20260910	13	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORD65E5AF984B	162	4	20260919	13	Pasta Alfredo	1	280.00	280.00	DELIVERED	COD
ORD5643F96569	124	17	20260730	20	Raita	3	40.00	120.00	DELIVERED	UPI
ORDC79B58951E	139	2	20260816	20	Miso Soup	1	150.00	150.00	PLACED	COD
ORDE8CF7DC8F9	165	9	20261004	21	Butter Naan	3	55.00	165.00	DELIVERED	COD
ORD88B7871999	166	3	20260821	12	Dal Makhani	1	220.00	220.00	DELIVERED	UPI
ORD2188DF6A5B	121	2	20260906	21	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	UPI
ORD257866985E	168	2	20260927	12	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	COD
ORDB6CBA7931E	169	17	20261007	19	Veg Biryani	1	220.00	220.00	DELIVERED	UPI
ORD955BFFBFBF	170	19	20260719	9	Idli Sambar	2	80.00	160.00	DELIVERED	CARD
ORDFDDACD8FAC	171	9	20261010	16	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORDB8F80EBF59	172	17	20261002	21	Chicken Biryani	1	280.00	280.00	PLACED	UPI
ORD3E4AB708CE	173	19	20260811	13	Masala Dosa	4	110.00	440.00	CANCELLED	UPI
ORD7CEEAE4CCA	174	3	20260723	8	Butter Chicken	4	320.00	1280.00	DELIVERED	UPI
ORD09E5F92183	175	9	20260820	12	Butter Naan	3	55.00	165.00	DELIVERED	CARD
ORDD7AA5A6D51	30	6	20260916	17	Chicken Wrap	4	140.00	560.00	DELIVERED	UPI
ORD451A4D930E	49	10	20260922	17	Fried Rice	1	180.00	180.00	DELIVERED	COD
ORDEC12A67D40	92	4	20260809	21	Garlic Bread	4	120.00	480.00	DELIVERED	UPI
ORD89CE3C8E76	179	2	20260925	22	Ramen Bowl	2	380.00	760.00	DELIVERED	COD
ORD81FA5EAD63	180	4	20260728	16	Pasta Alfredo	3	280.00	840.00	DELIVERED	UPI
ORD52094184C0	181	10	20260905	17	Manchurian	2	210.00	420.00	DELIVERED	UPI
ORDA468F901C1	182	17	20260716	19	Raita	3	40.00	120.00	DELIVERED	CARD
ORD40FE7AC855	183	4	20260718	14	Margherita Pizza	3	299.00	897.00	DELIVERED	UPI
ORD5EB460B149	184	9	20261004	20	Butter Naan	4	55.00	220.00	DELIVERED	COD
ORDB322A1C731	31	9	20260821	9	Butter Naan	1	55.00	55.00	DELIVERED	UPI
ORDB615EE3B4C	92	10	20260913	13	Fried Rice	4	180.00	720.00	DELIVERED	COD
ORD8773664DAB	187	3	20260804	21	Butter Chicken	2	320.00	640.00	DELIVERED	UPI
ORDB96214E23E	188	17	20260728	20	Raita	3	40.00	120.00	DELIVERED	COD
ORD689E47E7D4	45	2	20260921	21	Miso Soup	2	150.00	300.00	DELIVERED	COD
ORD4C66BC699C	139	2	20260810	14	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORDFCFDB005A1	28	9	20260918	22	Butter Naan	2	55.00	110.00	PLACED	UPI
ORD6D79C92B00	19	6	20260826	14	French Fries	4	90.00	360.00	PLACED	CARD
ORD31D1BE0157	193	6	20260808	9	French Fries	4	90.00	360.00	DELIVERED	COD
ORDEF596E308F	194	2	20260805	14	Ramen Bowl	4	380.00	1520.00	DELIVERED	UPI
ORD5CEBD05566	195	9	20260914	14	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORD887BBE35FF	196	19	20260802	20	Idli Sambar	3	80.00	240.00	DELIVERED	UPI
ORD97B7EBA034	197	19	20260717	17	Masala Dosa	2	110.00	220.00	DELIVERED	COD
ORD24AEAFEB48	198	19	20260717	16	Masala Dosa	1	110.00	110.00	DELIVERED	COD
ORD12F4A729E2	199	19	20260717	9	Filter Coffee	2	40.00	80.00	DELIVERED	COD
ORD424F271447	200	2	20260922	17	Ramen Bowl	4	380.00	1520.00	CANCELLED	UPI
ORDC8C2D90863	180	3	20260813	19	Dal Makhani	3	220.00	660.00	DELIVERED	CARD
ORD3CE47839E6	59	9	20260805	12	Tandoori Chicken	2	340.00	680.00	PLACED	CARD
ORD6749FD7861	203	2	20261008	13	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORDAD9828EE98	204	2	20260923	14	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	UPI
ORD6EDB7AD6DD	205	10	20260803	21	Hakka Noodles	3	190.00	570.00	DELIVERED	UPI
ORD61D413BE12	206	3	20260807	21	Dal Makhani	1	220.00	220.00	DELIVERED	CARD
ORD9B4AAE3AF2	95	4	20260714	14	Pasta Alfredo	1	280.00	280.00	DELIVERED	COD
ORDE00FD47938	100	2	20260717	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORD032394ED6F	199	17	20260906	21	Veg Biryani	3	220.00	660.00	DELIVERED	UPI
ORDB124647E58	210	17	20260727	17	Veg Biryani	2	220.00	440.00	DELIVERED	UPI
ORD1982C3121A	32	4	20260801	14	Pasta Alfredo	1	280.00	280.00	DELIVERED	CARD
ORDBD27B317B8	149	3	20260921	21	Dal Makhani	4	220.00	880.00	DELIVERED	COD
ORD5F5C8872D2	55	6	20260725	8	Cheese Burger	3	150.00	450.00	DELIVERED	CARD
ORD855F8E1B75	214	9	20260826	9	Butter Naan	1	55.00	55.00	DELIVERED	UPI
ORD5E3B52CAAE	215	9	20260910	13	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORD9CA999DE00	216	6	20261003	14	Chicken Wrap	3	140.00	420.00	DELIVERED	UPI
ORDDCCA98E8E8	37	6	20260830	21	French Fries	1	90.00	90.00	DELIVERED	UPI
ORDBF1FD31594	218	17	20260903	16	Veg Biryani	1	220.00	220.00	DELIVERED	COD
ORDC9C96BF350	219	17	20260910	19	Raita	1	40.00	40.00	DELIVERED	CARD
ORDC69D7A46B5	183	4	20260816	19	Margherita Pizza	1	299.00	299.00	DELIVERED	UPI
ORD6FD702208F	221	19	20260831	13	Filter Coffee	4	40.00	160.00	DELIVERED	UPI
ORD7B46E16029	216	17	20260904	20	Raita	3	40.00	120.00	CANCELLED	UPI
ORD56D7A1E220	160	4	20260717	20	Margherita Pizza	1	299.00	299.00	DELIVERED	CARD
ORDA23E7C5019	224	2	20260914	14	Veg Sushi Roll	2	350.00	700.00	DELIVERED	UPI
ORD1D86BF04AE	225	19	20260718	14	Masala Dosa	1	110.00	110.00	DELIVERED	CARD
ORDD399C97CF6	126	17	20260904	20	Raita	2	40.00	80.00	DELIVERED	UPI
ORD958F493AFD	227	19	20261010	20	Filter Coffee	4	40.00	160.00	DELIVERED	UPI
ORD171337D55C	99	19	20260927	13	Idli Sambar	3	80.00	240.00	PLACED	CARD
ORD14C85DF544	229	17	20260723	22	Raita	4	40.00	160.00	DELIVERED	UPI
ORD2F1C7B1FEC	146	4	20260814	9	Garlic Bread	1	120.00	120.00	DELIVERED	UPI
ORD9974E70D70	231	4	20260906	20	Garlic Bread	4	120.00	480.00	CANCELLED	UPI
ORD2A515A23E4	232	2	20260730	9	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD54C867FDA0	233	9	20260721	13	Paneer Butter Masala	2	250.00	500.00	DELIVERED	COD
ORD7AA6DE29B0	234	10	20260725	19	Manchurian	2	210.00	420.00	DELIVERED	COD
ORDFB773FA1D3	235	3	20260918	17	Butter Chicken	3	320.00	960.00	DELIVERED	COD
ORD7BAF7E921A	236	2	20260721	20	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORD70B406F7D5	180	10	20260925	13	Fried Rice	3	180.00	540.00	PLACED	CARD
ORD23FC8F1D51	130	4	20260911	21	Garlic Bread	2	120.00	240.00	DELIVERED	UPI
ORD3006B1D12E	98	2	20261006	9	Veg Sushi Roll	2	350.00	700.00	DELIVERED	COD
ORDEA920A68CB	152	17	20260805	22	Chicken Biryani	3	280.00	840.00	DELIVERED	COD
ORDB5D2CFACB1	182	17	20260903	17	Chicken Biryani	1	280.00	280.00	DELIVERED	CARD
ORDC15566E66D	242	10	20260805	21	Manchurian	3	210.00	630.00	DELIVERED	UPI
ORDB21F8894DA	243	3	20260714	14	Butter Chicken	1	320.00	320.00	DELIVERED	UPI
ORD73C7AFD923	116	9	20260913	17	Paneer Butter Masala	3	250.00	750.00	DELIVERED	CARD
ORD9F2DACBBEE	71	2	20260927	20	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD9674E79C13	246	2	20261001	13	Miso Soup	3	150.00	450.00	DELIVERED	UPI
ORDB719BEB888	21	17	20260829	17	Chicken Biryani	1	280.00	280.00	DELIVERED	COD
ORD8D1AC0C940	162	3	20260730	20	Garlic Naan	1	60.00	60.00	DELIVERED	UPI
ORD39F9F719A0	249	9	20260830	21	Butter Naan	2	55.00	110.00	DELIVERED	COD
ORDAD9FCA2F39	250	3	20260820	17	Paneer Tikka	1	260.00	260.00	DELIVERED	CARD
ORD771318B0CF	42	2	20260907	22	Ramen Bowl	1	380.00	380.00	DELIVERED	UPI
ORD76037BCA1C	54	17	20260726	21	Chicken Biryani	2	280.00	560.00	DELIVERED	UPI
ORDA7993AF069	253	17	20260816	17	Chicken Biryani	4	280.00	1120.00	DELIVERED	UPI
ORD9372CAC2DE	254	3	20260820	13	Dal Makhani	1	220.00	220.00	DELIVERED	UPI
ORD5FA1E36B5A	255	6	20260911	8	Chicken Wrap	4	140.00	560.00	DELIVERED	UPI
ORD34F88F6F5F	153	19	20260812	21	Filter Coffee	3	40.00	120.00	DELIVERED	UPI
ORD701BC8F8AC	41	19	20261004	17	Filter Coffee	3	40.00	120.00	DELIVERED	COD
ORD49860A6C71	258	17	20260727	8	Raita	4	40.00	160.00	DELIVERED	COD
ORDEA87587491	88	9	20260908	20	Butter Naan	4	55.00	220.00	DELIVERED	COD
ORD96ED264D3A	260	10	20260822	9	Manchurian	4	210.00	840.00	DELIVERED	CARD
ORD7DCEC333F9	34	10	20260905	13	Fried Rice	4	180.00	720.00	DELIVERED	UPI
ORD6576C6B8F1	262	6	20260811	21	Cheese Burger	1	150.00	150.00	DELIVERED	CARD
ORDE0BCA3DF4F	20	10	20260828	20	Hakka Noodles	4	190.00	760.00	DELIVERED	UPI
ORDA635B610EC	264	9	20260830	13	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	COD
ORD1BA485CC22	265	2	20260813	21	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD4F518BC568	157	9	20260720	16	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD6F25FA8082	267	10	20260728	22	Fried Rice	3	180.00	540.00	DELIVERED	CARD
ORDBD45247A76	171	2	20260906	19	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORDD0668D489A	269	4	20260831	22	Margherita Pizza	4	299.00	1196.00	DELIVERED	UPI
ORD3076C13F58	134	10	20260716	14	Manchurian	3	210.00	630.00	DELIVERED	UPI
ORDDFB271506A	195	2	20260725	22	Veg Sushi Roll	2	350.00	700.00	DELIVERED	COD
ORDEAF6C6DC1A	199	6	20261008	14	Cheese Burger	4	150.00	600.00	DELIVERED	UPI
ORD4447695595	98	9	20260925	21	Butter Naan	2	55.00	110.00	DELIVERED	UPI
ORD976DB40AB1	62	10	20260925	19	Hakka Noodles	4	190.00	760.00	DELIVERED	CARD
ORDC65340346A	275	9	20260915	12	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORD892F9180F9	276	19	20261009	21	Filter Coffee	2	40.00	80.00	DELIVERED	COD
ORD8F5C2E6BB8	30	6	20260815	21	French Fries	3	90.00	270.00	DELIVERED	UPI
ORD7D4E77C43F	146	10	20260716	22	Fried Rice	2	180.00	360.00	DELIVERED	UPI
ORD870DC56066	95	3	20260807	20	Garlic Naan	2	60.00	120.00	DELIVERED	COD
ORDB0BDF95BAA	102	2	20260830	21	Veg Sushi Roll	2	350.00	700.00	CANCELLED	UPI
ORDCE0C2704EF	184	2	20261006	20	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORDF7CA009B6D	282	9	20260916	8	Butter Naan	1	55.00	55.00	CANCELLED	UPI
ORD2F3637B6BC	283	19	20261007	20	Idli Sambar	3	80.00	240.00	DELIVERED	COD
ORDF6D19FA0BF	284	4	20260905	17	Margherita Pizza	2	299.00	598.00	CANCELLED	UPI
ORD6AF36EB383	135	9	20260827	20	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD8152B60D88	286	2	20260904	13	Miso Soup	3	150.00	450.00	DELIVERED	CARD
ORD0A68626F15	287	4	20260906	14	Garlic Bread	1	120.00	120.00	DELIVERED	CARD
ORD91B365FB70	288	3	20260902	13	Dal Makhani	2	220.00	440.00	DELIVERED	CARD
ORDA2FC58C78A	289	9	20260901	14	Butter Naan	1	55.00	55.00	DELIVERED	CARD
ORD3A6D26A2C6	290	17	20260909	9	Raita	4	40.00	160.00	CANCELLED	UPI
ORDD7E073346A	117	3	20260822	13	Butter Chicken	2	320.00	640.00	DELIVERED	CARD
ORD3CAE130E03	292	10	20260903	8	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORD3509DDCAD7	45	9	20260713	13	Tandoori Chicken	4	340.00	1360.00	DELIVERED	CARD
ORD6A14EAF494	187	3	20260806	21	Paneer Tikka	4	260.00	1040.00	DELIVERED	UPI
ORD024391C636	295	2	20260716	8	Ramen Bowl	1	380.00	380.00	DELIVERED	COD
ORDF5DC9E2BFD	296	6	20260729	12	French Fries	1	90.00	90.00	DELIVERED	COD
ORD89F1DEE622	16	2	20260817	13	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	CARD
ORDAF67A95944	298	3	20260717	16	Garlic Naan	3	60.00	180.00	DELIVERED	UPI
ORD1F2B9FADA5	267	10	20260721	8	Manchurian	3	210.00	630.00	DELIVERED	CARD
ORD9F24F6B916	289	9	20260825	21	Paneer Butter Masala	1	250.00	250.00	PLACED	UPI
ORD522DCAB7C4	258	6	20260907	14	Cheese Burger	4	150.00	600.00	DELIVERED	UPI
ORDF9F3DEB1D9	174	10	20260822	13	Fried Rice	3	180.00	540.00	DELIVERED	COD
ORD1F27C2C6F7	133	3	20260908	21	Butter Chicken	1	320.00	320.00	DELIVERED	COD
ORDB402EED28A	72	10	20261007	21	Hakka Noodles	3	190.00	570.00	DELIVERED	UPI
ORDFBC22C7A27	180	10	20260728	21	Hakka Noodles	3	190.00	570.00	PLACED	UPI
ORDDF481E77BA	144	2	20260929	14	Miso Soup	1	150.00	150.00	DELIVERED	COD
ORD04EA2B5443	109	4	20260828	9	Garlic Bread	3	120.00	360.00	DELIVERED	COD
ORD40631DE4C9	160	10	20260803	17	Hakka Noodles	1	190.00	190.00	DELIVERED	UPI
ORD66152D7017	151	6	20260822	22	Cheese Burger	2	150.00	300.00	DELIVERED	UPI
ORD32AD8EA268	310	2	20260717	12	Ramen Bowl	3	380.00	1140.00	DELIVERED	CARD
ORD34A98FF28A	264	9	20260920	19	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORD59D6BCB90B	34	10	20261001	9	Hakka Noodles	4	190.00	760.00	DELIVERED	UPI
ORD5F00C378B0	313	6	20260911	21	Chicken Wrap	1	140.00	140.00	DELIVERED	COD
ORDB5612D5260	235	3	20260818	13	Butter Chicken	4	320.00	1280.00	DELIVERED	UPI
ORD433D1529EB	18	2	20260905	16	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORD08F10FF020	157	9	20260830	21	Tandoori Chicken	1	340.00	340.00	DELIVERED	CARD
ORD3F5209A074	317	2	20260921	12	Veg Sushi Roll	1	350.00	350.00	DELIVERED	COD
ORDF92B7D4B96	172	17	20260802	17	Raita	3	40.00	120.00	CANCELLED	COD
ORD5F3FC2DA5C	72	4	20260822	8	Margherita Pizza	3	299.00	897.00	DELIVERED	UPI
ORD8CE5859BA7	320	10	20260802	12	Fried Rice	2	180.00	360.00	DELIVERED	CARD
ORD249E93DB9C	236	9	20260809	21	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORDAD06D9099D	7	3	20260720	21	Garlic Naan	3	60.00	180.00	DELIVERED	UPI
ORDBFEF504B4D	225	17	20260918	22	Chicken Biryani	3	280.00	840.00	DELIVERED	UPI
ORDA4866A95A3	180	10	20260923	14	Manchurian	3	210.00	630.00	DELIVERED	UPI
ORD57F59A926D	325	17	20260907	19	Raita	3	40.00	120.00	DELIVERED	UPI
ORDEFF018285F	326	19	20260811	20	Idli Sambar	2	80.00	160.00	DELIVERED	COD
ORD96841D0D5F	327	6	20260911	19	Chicken Wrap	4	140.00	560.00	DELIVERED	UPI
ORD5C9DE64A76	53	17	20261003	14	Chicken Biryani	3	280.00	840.00	DELIVERED	COD
ORD091A25121F	329	19	20260913	14	Idli Sambar	1	80.00	80.00	DELIVERED	UPI
ORDF1B44BE16A	65	17	20260910	19	Veg Biryani	1	220.00	220.00	DELIVERED	COD
ORDFD8E3316F6	33	6	20260810	14	Chicken Wrap	1	140.00	140.00	DELIVERED	CARD
ORDFAE8E313F6	332	10	20260913	14	Fried Rice	4	180.00	720.00	DELIVERED	COD
ORD6E1FED5F8A	255	17	20260906	21	Veg Biryani	1	220.00	220.00	DELIVERED	COD
ORDEF1679AB27	145	6	20260729	14	Chicken Wrap	1	140.00	140.00	DELIVERED	COD
ORD75E36D6C5A	166	10	20260715	21	Fried Rice	1	180.00	180.00	DELIVERED	UPI
ORDEF56C3F343	32	3	20261003	9	Butter Chicken	1	320.00	320.00	DELIVERED	UPI
ORD0701DDB308	203	9	20261004	21	Tandoori Chicken	3	340.00	1020.00	DELIVERED	CARD
ORDFF9833EE17	242	10	20261003	9	Manchurian	3	210.00	630.00	DELIVERED	CARD
ORDE2CC0BBD2E	260	4	20260904	19	Pasta Alfredo	4	280.00	1120.00	DELIVERED	CARD
ORD29A969FC72	340	9	20260825	20	Tandoori Chicken	4	340.00	1360.00	DELIVERED	COD
ORD95391A5943	341	10	20260805	17	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORDCC91071E2F	342	10	20260805	21	Fried Rice	4	180.00	720.00	CANCELLED	COD
ORDC2CB3C5341	325	17	20260924	20	Veg Biryani	1	220.00	220.00	CANCELLED	COD
ORD10E596EC97	344	9	20260810	20	Paneer Butter Masala	4	250.00	1000.00	CANCELLED	COD
ORDB4DA171522	229	17	20260801	9	Raita	4	40.00	160.00	DELIVERED	COD
ORDF5673BC0E4	346	9	20260821	21	Tandoori Chicken	1	340.00	340.00	DELIVERED	CARD
ORD93BA03B3F4	347	19	20260722	21	Filter Coffee	3	40.00	120.00	DELIVERED	COD
ORD69E436C7D8	348	9	20260807	19	Tandoori Chicken	3	340.00	1020.00	DELIVERED	COD
ORD9A2990E3C8	198	6	20260911	17	Cheese Burger	2	150.00	300.00	DELIVERED	CARD
ORD25A762F2B7	229	17	20260919	9	Veg Biryani	2	220.00	440.00	DELIVERED	COD
ORD75DF9DA1F4	351	3	20260812	8	Dal Makhani	1	220.00	220.00	DELIVERED	UPI
ORD9B762DF961	352	10	20260902	21	Fried Rice	3	180.00	540.00	DELIVERED	COD
ORD4E1D3F856B	353	17	20260814	20	Raita	2	40.00	80.00	DELIVERED	UPI
ORD7B77A4178B	354	9	20260731	22	Tandoori Chicken	2	340.00	680.00	DELIVERED	UPI
ORD34B07C462C	355	2	20260825	13	Ramen Bowl	1	380.00	380.00	CANCELLED	UPI
ORD5004642540	356	6	20260907	21	Cheese Burger	3	150.00	450.00	DELIVERED	UPI
ORD6FB0AA42DE	246	9	20260817	21	Paneer Butter Masala	1	250.00	250.00	PLACED	CARD
ORD2899398817	183	10	20260810	8	Hakka Noodles	1	190.00	190.00	DELIVERED	UPI
ORD410C3B4882	4	4	20260904	19	Margherita Pizza	4	299.00	1196.00	DELIVERED	UPI
ORDF31A225CBE	360	2	20260714	13	Ramen Bowl	4	380.00	1520.00	DELIVERED	CARD
ORD597DE13A89	361	3	20261009	13	Paneer Tikka	2	260.00	520.00	DELIVERED	CARD
ORDF9A75C7895	362	9	20260723	9	Tandoori Chicken	3	340.00	1020.00	DELIVERED	CARD
ORD2F17E687CE	175	9	20260926	20	Butter Naan	3	55.00	165.00	DELIVERED	CARD
ORD82B8FB880A	10	3	20260811	20	Dal Makhani	3	220.00	660.00	DELIVERED	UPI
ORDBF45F5133C	342	3	20260924	16	Dal Makhani	1	220.00	220.00	DELIVERED	CARD
ORD746AA70212	26	6	20260725	22	French Fries	2	90.00	180.00	DELIVERED	CARD
ORDDE76CA6C84	367	10	20260721	16	Fried Rice	1	180.00	180.00	DELIVERED	UPI
ORD320B78C5B5	354	9	20260730	13	Butter Naan	1	55.00	55.00	DELIVERED	UPI
ORD5E3ACD64F9	369	3	20260825	16	Paneer Tikka	4	260.00	1040.00	DELIVERED	UPI
ORDEFF6491F57	292	4	20260927	8	Margherita Pizza	3	299.00	897.00	DELIVERED	COD
ORD8778EEEFD6	371	2	20261001	13	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	UPI
ORD5263E6549C	283	19	20260831	20	Idli Sambar	2	80.00	160.00	DELIVERED	CARD
ORD4F74A0BC49	21	19	20260721	14	Filter Coffee	2	40.00	80.00	PLACED	UPI
ORD68F057EFE2	249	2	20260801	22	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD2DD3E4A136	254	3	20260930	19	Dal Makhani	4	220.00	880.00	DELIVERED	COD
ORDA52EE95E31	120	9	20260730	21	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORD0DD778BCFC	283	19	20260716	22	Filter Coffee	1	40.00	40.00	DELIVERED	COD
ORDD5353BFE5D	378	6	20260831	9	Cheese Burger	1	150.00	150.00	DELIVERED	CARD
ORDE869B31EDE	379	19	20261007	20	Idli Sambar	3	80.00	240.00	DELIVERED	CARD
ORD025DC2AD41	152	17	20260812	21	Chicken Biryani	1	280.00	280.00	DELIVERED	UPI
ORD01B615163C	17	19	20260906	20	Filter Coffee	4	40.00	160.00	DELIVERED	UPI
ORD87B8E46F6B	153	17	20260727	14	Raita	1	40.00	40.00	DELIVERED	CARD
ORD7FE63D3E65	332	10	20260823	19	Hakka Noodles	3	190.00	570.00	DELIVERED	CARD
ORDC28B2523C7	183	10	20260927	14	Fried Rice	1	180.00	180.00	DELIVERED	UPI
ORD3782F06FA8	37	19	20260805	22	Filter Coffee	4	40.00	160.00	DELIVERED	UPI
ORDABBDFDFB17	356	17	20260827	17	Veg Biryani	3	220.00	660.00	DELIVERED	COD
ORDBFD9B18817	173	6	20261004	9	French Fries	2	90.00	180.00	DELIVERED	CARD
ORD7F8BDD4C99	387	3	20260904	21	Dal Makhani	3	220.00	660.00	DELIVERED	UPI
ORDF60DF5237D	388	4	20260924	19	Garlic Bread	3	120.00	360.00	DELIVERED	UPI
ORD43424A77AF	275	2	20260830	13	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORD7F7731464A	390	2	20260828	16	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	CARD
ORD4570924811	290	6	20260730	20	Cheese Burger	4	150.00	600.00	DELIVERED	UPI
ORD72F353BA0E	392	6	20260715	20	French Fries	1	90.00	90.00	DELIVERED	CARD
ORD735CA20C4E	362	2	20260803	13	Ramen Bowl	2	380.00	760.00	PLACED	UPI
ORD9BD44CC875	394	10	20260720	13	Manchurian	1	210.00	210.00	DELIVERED	CARD
ORDFC6D2D58E7	127	6	20260825	13	Cheese Burger	3	150.00	450.00	DELIVERED	COD
ORD51D2448B8C	76	3	20260916	19	Butter Chicken	4	320.00	1280.00	DELIVERED	COD
ORD2E62A1B395	108	10	20260930	13	Fried Rice	2	180.00	360.00	DELIVERED	CARD
ORDF6960D972C	398	4	20260718	20	Pasta Alfredo	2	280.00	560.00	DELIVERED	COD
ORD3951F9511A	392	6	20260801	14	French Fries	1	90.00	90.00	DELIVERED	CARD
ORD2C2306D778	400	6	20260926	19	Chicken Wrap	3	140.00	420.00	DELIVERED	UPI
ORDED13F67107	27	6	20261009	17	French Fries	2	90.00	180.00	DELIVERED	COD
ORD7D8FB5D2D0	402	19	20260816	13	Masala Dosa	4	110.00	440.00	DELIVERED	COD
ORDF395696AA1	3	4	20260805	13	Pasta Alfredo	2	280.00	560.00	DELIVERED	CARD
ORDB992BA8026	404	3	20260722	12	Garlic Naan	3	60.00	180.00	CANCELLED	UPI
ORD3C349944B2	16	2	20260717	12	Veg Sushi Roll	2	350.00	700.00	DELIVERED	COD
ORDCBCDE0342D	406	3	20260904	22	Garlic Naan	2	60.00	120.00	DELIVERED	UPI
ORDA56EF7B3BF	407	4	20260715	13	Pasta Alfredo	3	280.00	840.00	DELIVERED	CARD
ORD585867F7B3	408	4	20260816	17	Margherita Pizza	2	299.00	598.00	DELIVERED	CARD
ORD4909117A2A	409	3	20261007	22	Garlic Naan	2	60.00	120.00	DELIVERED	UPI
ORDA0CB2E6F90	200	9	20260821	19	Tandoori Chicken	1	340.00	340.00	DELIVERED	COD
ORD6E3801AF44	411	3	20260903	17	Paneer Tikka	4	260.00	1040.00	DELIVERED	CARD
ORDAF367DAB19	147	2	20260723	16	Veg Sushi Roll	2	350.00	700.00	DELIVERED	UPI
ORD7661D03D7C	242	4	20261004	22	Pasta Alfredo	3	280.00	840.00	DELIVERED	UPI
ORD20D6FC321E	175	9	20260821	13	Paneer Butter Masala	1	250.00	250.00	DELIVERED	COD
ORD3FE9436E4F	415	2	20260803	20	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORD10B8C2C300	416	19	20261010	20	Filter Coffee	3	40.00	120.00	DELIVERED	CARD
ORDF5E611A0C2	417	19	20260828	12	Masala Dosa	2	110.00	220.00	DELIVERED	CARD
ORD1EC48A584D	253	19	20260718	12	Filter Coffee	2	40.00	80.00	DELIVERED	COD
ORDE19AF2A93D	417	19	20260906	21	Masala Dosa	2	110.00	220.00	DELIVERED	COD
ORDF6CE0A4B6C	420	4	20260911	16	Pasta Alfredo	2	280.00	560.00	DELIVERED	CARD
ORD621125EE3F	421	19	20260722	12	Masala Dosa	2	110.00	220.00	DELIVERED	UPI
ORDE49E05B743	174	4	20260930	17	Pasta Alfredo	2	280.00	560.00	DELIVERED	UPI
ORD1ADAF38AC2	22	3	20260807	9	Paneer Tikka	4	260.00	1040.00	CANCELLED	UPI
ORDE8FCAA7863	424	17	20260715	13	Chicken Biryani	4	280.00	1120.00	DELIVERED	UPI
ORDA50087A40F	425	2	20260803	17	Miso Soup	4	150.00	600.00	DELIVERED	COD
ORDECDC2EA923	354	2	20260724	21	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORD37E7BFDA6F	227	6	20260816	20	Cheese Burger	4	150.00	600.00	DELIVERED	COD
ORD736C3E70F5	48	4	20260924	20	Garlic Bread	4	120.00	480.00	DELIVERED	COD
ORDB48E5BEC7D	258	19	20260927	22	Idli Sambar	3	80.00	240.00	DELIVERED	UPI
ORDB7CA06000A	430	9	20260725	12	Paneer Butter Masala	4	250.00	1000.00	CANCELLED	UPI
ORDCF3C72DA23	199	17	20260718	21	Raita	4	40.00	160.00	DELIVERED	COD
ORD3996DE1DFE	394	4	20261007	13	Margherita Pizza	3	299.00	897.00	DELIVERED	COD
ORDCA6C6A6F04	332	3	20260925	9	Dal Makhani	3	220.00	660.00	DELIVERED	UPI
ORD97ADB0E462	434	2	20260717	16	Ramen Bowl	3	380.00	1140.00	CANCELLED	COD
ORD851E0281FF	255	6	20260818	8	French Fries	3	90.00	270.00	CANCELLED	UPI
ORD340CE38C7D	53	6	20260907	12	Cheese Burger	1	150.00	150.00	DELIVERED	COD
ORDF02E1B07A8	101	9	20260819	17	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORD6C28FE1EC6	438	9	20260826	21	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD5B29574403	59	2	20260925	20	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	CARD
ORD09BCBAEB1B	92	10	20260930	20	Fried Rice	2	180.00	360.00	CANCELLED	COD
ORDC506F07596	441	4	20260908	13	Garlic Bread	3	120.00	360.00	DELIVERED	UPI
ORD03CB00DBBF	111	6	20261008	21	Cheese Burger	1	150.00	150.00	DELIVERED	COD
ORD6C981C6130	443	2	20260803	13	Miso Soup	2	150.00	300.00	DELIVERED	COD
ORDE88B161BFE	371	9	20261006	20	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	CARD
ORDA927D95768	445	2	20260821	16	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	COD
ORD4FFA77E5F5	114	10	20260717	21	Hakka Noodles	2	190.00	380.00	DELIVERED	UPI
ORD9D66256430	447	2	20260714	14	Ramen Bowl	1	380.00	380.00	DELIVERED	COD
ORD07AB09D9F4	448	17	20260716	20	Veg Biryani	2	220.00	440.00	DELIVERED	COD
ORD703E2E65C4	133	4	20260907	16	Pasta Alfredo	2	280.00	560.00	DELIVERED	CARD
ORDE8727232A0	450	10	20261002	21	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORD2D9FE088FC	451	3	20260826	20	Butter Chicken	2	320.00	640.00	DELIVERED	COD
ORD8B0DDF1E72	214	2	20260721	8	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	UPI
ORDE8AB1F0F66	453	4	20260911	21	Garlic Bread	3	120.00	360.00	DELIVERED	COD
ORD107181C18D	92	3	20260929	21	Paneer Tikka	1	260.00	260.00	DELIVERED	COD
ORD8608D91AF5	35	3	20260809	17	Dal Makhani	4	220.00	880.00	DELIVERED	CARD
ORDB562E65217	456	10	20260807	20	Manchurian	3	210.00	630.00	DELIVERED	UPI
ORDBC788FCECD	340	2	20260821	13	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	COD
ORD7B0692FD03	367	3	20260713	16	Dal Makhani	1	220.00	220.00	DELIVERED	UPI
ORDB609F6D42C	47	10	20260822	20	Manchurian	2	210.00	420.00	DELIVERED	CARD
ORD25D13F641F	30	6	20261009	8	Chicken Wrap	2	140.00	280.00	DELIVERED	CARD
ORD9F3B950BAF	438	2	20261002	13	Miso Soup	1	150.00	150.00	DELIVERED	COD
ORD601DB1EEF0	342	10	20260817	14	Hakka Noodles	1	190.00	190.00	DELIVERED	COD
ORDCD2167AE7F	166	3	20260828	21	Paneer Tikka	4	260.00	1040.00	DELIVERED	UPI
ORD1575C31E18	225	19	20260821	14	Idli Sambar	2	80.00	160.00	PLACED	COD
ORDAC846AFF93	465	2	20260814	16	Veg Sushi Roll	2	350.00	700.00	DELIVERED	CARD
ORDA2AF9DC806	60	17	20260909	20	Chicken Biryani	2	280.00	560.00	DELIVERED	UPI
ORD041D082AB9	467	3	20260922	14	Dal Makhani	2	220.00	440.00	DELIVERED	COD
ORDBB9AB0B5D9	468	10	20260920	13	Fried Rice	3	180.00	540.00	CANCELLED	COD
ORDF9CE1840CC	117	3	20260814	8	Paneer Tikka	3	260.00	780.00	DELIVERED	CARD
ORD1B8683D721	295	9	20260720	9	Tandoori Chicken	2	340.00	680.00	DELIVERED	UPI
ORDE68FBECE63	260	4	20260814	13	Pasta Alfredo	1	280.00	280.00	DELIVERED	UPI
ORD89A01251C4	420	4	20260722	13	Garlic Bread	2	120.00	240.00	DELIVERED	UPI
ORDA0099545C5	235	4	20260826	20	Garlic Bread	4	120.00	480.00	DELIVERED	UPI
ORDA8ACF171AE	474	4	20261001	22	Margherita Pizza	3	299.00	897.00	DELIVERED	CARD
ORD1AE837A178	262	6	20260821	9	Chicken Wrap	2	140.00	280.00	DELIVERED	COD
ORDC4481C632C	448	6	20260811	8	Chicken Wrap	3	140.00	420.00	DELIVERED	UPI
ORD6EE8BF2882	180	4	20260802	12	Garlic Bread	4	120.00	480.00	DELIVERED	UPI
ORDC923553C4E	262	6	20260720	20	French Fries	3	90.00	270.00	DELIVERED	COD
ORDFDA454D206	264	2	20260829	22	Ramen Bowl	4	380.00	1520.00	CANCELLED	CARD
ORD8513E5FB82	480	9	20261002	21	Tandoori Chicken	3	340.00	1020.00	DELIVERED	COD
ORDF835851080	8	4	20260714	8	Margherita Pizza	2	299.00	598.00	DELIVERED	UPI
ORDFE0DB09CD7	448	19	20260815	9	Masala Dosa	3	110.00	330.00	DELIVERED	COD
ORD0361168A08	483	3	20260902	8	Butter Chicken	2	320.00	640.00	DELIVERED	UPI
ORD0AD12D4F98	249	9	20260901	16	Paneer Butter Masala	1	250.00	250.00	DELIVERED	COD
ORD48098247A1	485	17	20260723	16	Chicken Biryani	4	280.00	1120.00	DELIVERED	CARD
ORD0667499D94	486	19	20261004	21	Idli Sambar	1	80.00	80.00	DELIVERED	UPI
ORD17E30491ED	487	2	20260801	16	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORDE660C7AFD9	488	4	20260823	13	Garlic Bread	4	120.00	480.00	DELIVERED	CARD
ORD7B7B09FF82	160	4	20260904	19	Pasta Alfredo	4	280.00	1120.00	DELIVERED	COD
ORD9308D08B4E	32	3	20260731	21	Garlic Naan	4	60.00	240.00	DELIVERED	COD
ORD7AFE762E85	258	6	20260717	17	French Fries	3	90.00	270.00	DELIVERED	UPI
ORDFC3F67EE20	135	9	20260811	20	Butter Naan	4	55.00	220.00	DELIVERED	UPI
ORD93B426AF0C	54	17	20261005	13	Chicken Biryani	2	280.00	560.00	DELIVERED	UPI
ORD32A3AEE740	494	9	20260716	9	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD393836E290	45	9	20260905	14	Tandoori Chicken	1	340.00	340.00	DELIVERED	COD
ORDAF39006971	275	2	20260728	9	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD34585BA2E7	497	17	20260820	9	Chicken Biryani	3	280.00	840.00	DELIVERED	UPI
ORDB32B5CC7CD	480	2	20260805	20	Miso Soup	2	150.00	300.00	DELIVERED	CARD
ORD87DC13A547	153	17	20260912	19	Chicken Biryani	2	280.00	560.00	DELIVERED	COD
ORD022B0C1014	77	4	20260805	9	Margherita Pizza	1	299.00	299.00	DELIVERED	UPI
ORDBB9E7D830B	32	10	20261001	14	Manchurian	2	210.00	420.00	DELIVERED	CARD
ORD8F62A1E4DB	286	9	20260813	19	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORDA42CC5AC99	55	19	20260731	9	Masala Dosa	3	110.00	330.00	DELIVERED	CARD
ORDE6343827B4	504	2	20260831	13	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORDF3017206C3	505	6	20260918	13	French Fries	2	90.00	180.00	DELIVERED	UPI
ORD978CA40844	66	4	20261007	19	Garlic Bread	2	120.00	240.00	DELIVERED	CARD
ORD16980F6651	327	19	20260806	20	Idli Sambar	3	80.00	240.00	DELIVERED	COD
ORDB19D067622	31	9	20260916	20	Butter Naan	4	55.00	220.00	DELIVERED	UPI
ORD80D307047E	465	9	20260928	14	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORD0C154C9ADF	441	4	20260827	20	Garlic Bread	4	120.00	480.00	DELIVERED	UPI
ORD92C70F9644	511	10	20260809	20	Fried Rice	1	180.00	180.00	DELIVERED	CARD
ORD614118B407	224	9	20260910	13	Paneer Butter Masala	1	250.00	250.00	DELIVERED	UPI
ORD54A4C5E0D6	146	4	20260729	13	Margherita Pizza	3	299.00	897.00	DELIVERED	UPI
ORD49C1B9A291	514	9	20260924	14	Tandoori Chicken	2	340.00	680.00	DELIVERED	CARD
ORD9762A16916	515	3	20260921	9	Butter Chicken	1	320.00	320.00	DELIVERED	UPI
ORD070B3D4D48	224	9	20261006	13	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORDACEB654619	184	2	20261002	21	Veg Sushi Roll	2	350.00	700.00	DELIVERED	COD
ORD3888CA18D3	282	2	20260922	16	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORD1F5EAF9C3E	267	10	20260826	19	Manchurian	4	210.00	840.00	DELIVERED	UPI
ORD3A3F553EE7	121	9	20260819	21	Paneer Butter Masala	2	250.00	500.00	DELIVERED	COD
ORD70DB12F854	17	17	20261005	19	Veg Biryani	3	220.00	660.00	DELIVERED	CARD
ORD276703C980	522	10	20261004	9	Hakka Noodles	3	190.00	570.00	DELIVERED	UPI
ORD17BC54ECEB	111	6	20260714	21	Chicken Wrap	1	140.00	140.00	DELIVERED	COD
ORDB0499341BA	24	19	20260814	13	Filter Coffee	2	40.00	80.00	DELIVERED	UPI
ORD28A51B5934	525	10	20260820	17	Manchurian	4	210.00	840.00	CANCELLED	CARD
ORD020EB11630	525	4	20260917	13	Pasta Alfredo	2	280.00	560.00	DELIVERED	CARD
ORD216363F08A	527	9	20260724	8	Tandoori Chicken	2	340.00	680.00	DELIVERED	UPI
ORD1AF30C7D6B	28	9	20260901	14	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORDEE5480B944	65	6	20260820	22	French Fries	4	90.00	360.00	CANCELLED	UPI
ORDCA527E9631	387	10	20260816	13	Fried Rice	3	180.00	540.00	CANCELLED	UPI
ORDCF96205BBB	531	3	20260909	21	Dal Makhani	4	220.00	880.00	DELIVERED	UPI
ORDBD674B9714	532	6	20260731	22	Cheese Burger	4	150.00	600.00	PLACED	UPI
ORDB7ECF54603	533	17	20260814	9	Raita	4	40.00	160.00	DELIVERED	COD
ORDF726EEEC7B	534	17	20260923	20	Veg Biryani	4	220.00	880.00	DELIVERED	CARD
ORD628448FA21	535	2	20260918	19	Ramen Bowl	1	380.00	380.00	DELIVERED	COD
ORD442177DE3F	441	3	20260829	12	Paneer Tikka	1	260.00	260.00	DELIVERED	UPI
ORDB12B465BFD	49	10	20260925	13	Manchurian	4	210.00	840.00	DELIVERED	COD
ORDF42C0EDA66	255	17	20261003	12	Veg Biryani	1	220.00	220.00	CANCELLED	COD
ORD043ACBAD67	26	17	20260923	19	Chicken Biryani	1	280.00	280.00	DELIVERED	UPI
ORD91EF08507E	99	6	20260915	21	French Fries	3	90.00	270.00	PLACED	COD
ORD0B3C1B4A29	146	3	20260806	21	Butter Chicken	4	320.00	1280.00	DELIVERED	UPI
ORDFFAA60AEE6	243	10	20260921	20	Fried Rice	4	180.00	720.00	DELIVERED	COD
ORD0291384546	172	6	20260912	22	Cheese Burger	2	150.00	300.00	DELIVERED	UPI
ORDCDB0A3FDB3	545	10	20260907	21	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORD8944EDFA13	52	3	20260812	20	Garlic Naan	1	60.00	60.00	DELIVERED	COD
ORD86682717DA	196	17	20260802	8	Raita	1	40.00	40.00	DELIVERED	UPI
ORD413220369A	140	9	20260713	14	Butter Naan	1	55.00	55.00	DELIVERED	COD
ORD75DBCD6946	549	6	20261003	16	Cheese Burger	4	150.00	600.00	DELIVERED	CARD
ORD0B24DD224F	65	17	20260828	14	Veg Biryani	2	220.00	440.00	DELIVERED	UPI
ORD4A80C3B24C	551	6	20260918	20	Cheese Burger	3	150.00	450.00	DELIVERED	UPI
ORDFF127EBC68	152	6	20260928	21	French Fries	2	90.00	180.00	DELIVERED	COD
ORD41C3CE7058	204	2	20260802	12	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORD276AFCD8AE	448	19	20260716	19	Filter Coffee	4	40.00	160.00	DELIVERED	UPI
ORD2743CDB04D	59	2	20260928	20	Ramen Bowl	4	380.00	1520.00	DELIVERED	COD
ORDE02CEEA879	56	3	20260811	21	Garlic Naan	1	60.00	60.00	DELIVERED	COD
ORD9DE6C1B98E	557	9	20261009	22	Tandoori Chicken	2	340.00	680.00	DELIVERED	COD
ORD5FEB5F32B4	37	6	20260828	14	Cheese Burger	3	150.00	450.00	DELIVERED	CARD
ORD07274AFCCD	559	2	20260928	14	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	CARD
ORD02BB0610A6	126	19	20260723	20	Filter Coffee	4	40.00	160.00	DELIVERED	COD
ORD7448FAB15A	561	10	20260816	12	Manchurian	4	210.00	840.00	DELIVERED	COD
ORDFB1CD9D8C7	562	19	20261004	8	Idli Sambar	2	80.00	160.00	DELIVERED	CARD
ORD3928EEEC10	46	4	20260721	9	Margherita Pizza	1	299.00	299.00	DELIVERED	UPI
ORD6142918805	235	9	20260804	21	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORD6F7793E17D	35	2	20260901	17	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	UPI
ORD18D3806DC7	171	3	20260915	14	Butter Chicken	1	320.00	320.00	DELIVERED	COD
ORD881A6B03A7	153	4	20260826	21	Margherita Pizza	1	299.00	299.00	DELIVERED	CARD
ORDAE6ECA9B01	267	4	20260917	13	Pasta Alfredo	3	280.00	840.00	DELIVERED	UPI
ORDA4187BC319	569	6	20260907	9	Chicken Wrap	2	140.00	280.00	DELIVERED	UPI
ORDE44EC9E001	535	10	20260729	17	Manchurian	2	210.00	420.00	DELIVERED	COD
ORD24E0E492B7	480	9	20261001	9	Butter Naan	4	55.00	220.00	CANCELLED	COD
ORD75550C417B	354	2	20260908	22	Miso Soup	4	150.00	600.00	DELIVERED	CARD
ORD282F267214	379	6	20260925	13	Cheese Burger	2	150.00	300.00	DELIVERED	CARD
ORD39F7721C31	204	9	20260829	13	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	CARD
ORDF8DBD6640B	532	6	20260821	13	French Fries	1	90.00	90.00	DELIVERED	COD
ORDF3FA3AE223	33	6	20261002	20	Cheese Burger	1	150.00	150.00	CANCELLED	CARD
ORD77BAD207FE	32	2	20261010	21	Ramen Bowl	3	380.00	1140.00	DELIVERED	COD
ORD9125134CD8	578	4	20260818	17	Garlic Bread	4	120.00	480.00	DELIVERED	UPI
ORD25D3C6C39B	265	2	20260930	9	Ramen Bowl	1	380.00	380.00	DELIVERED	CARD
ORDBAF692366C	580	4	20260727	16	Margherita Pizza	4	299.00	1196.00	DELIVERED	UPI
ORD023C4F2CE5	535	3	20260808	19	Dal Makhani	4	220.00	880.00	DELIVERED	COD
ORDADF5C31054	234	6	20260818	16	French Fries	3	90.00	270.00	DELIVERED	COD
ORD47162E6EDD	580	3	20261006	16	Butter Chicken	2	320.00	640.00	DELIVERED	UPI
ORD1042BA7473	450	2	20260822	22	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	CARD
ORDDDDB4E9A05	456	9	20260718	19	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORDB8989D1491	195	2	20260810	13	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	COD
ORD1F68092B3C	587	6	20261007	20	Chicken Wrap	2	140.00	280.00	DELIVERED	COD
ORD3751AC38AB	588	17	20260920	19	Chicken Biryani	1	280.00	280.00	DELIVERED	UPI
ORD8995188888	313	10	20260904	21	Hakka Noodles	3	190.00	570.00	DELIVERED	CARD
ORD4E316F5780	72	3	20260927	19	Dal Makhani	4	220.00	880.00	DELIVERED	UPI
ORD4FC11CAA73	97	2	20260826	21	Ramen Bowl	2	380.00	760.00	DELIVERED	COD
ORD2E8E335192	203	9	20261005	20	Butter Naan	2	55.00	110.00	DELIVERED	UPI
ORD32A8CBE316	593	9	20261001	8	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD888590397A	39	3	20260809	13	Paneer Tikka	4	260.00	1040.00	DELIVERED	COD
ORDC2ACE9C3D8	157	10	20260809	20	Fried Rice	2	180.00	360.00	DELIVERED	UPI
ORD9FB04E2CEA	77	6	20260922	22	Chicken Wrap	3	140.00	420.00	DELIVERED	COD
ORDDE6BA9C976	406	4	20260914	20	Pasta Alfredo	1	280.00	280.00	DELIVERED	COD
ORDCA9A9CE46F	598	9	20260908	17	Tandoori Chicken	4	340.00	1360.00	DELIVERED	CARD
ORD760BB50B10	180	2	20260915	20	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD2329882884	351	2	20260808	9	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD11CB70F543	196	9	20260731	13	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	CARD
ORDE52A710878	416	10	20261008	13	Hakka Noodles	4	190.00	760.00	DELIVERED	CARD
ORDCD203859B3	2	4	20260930	21	Margherita Pizza	2	299.00	598.00	DELIVERED	UPI
ORD4D0303EBE1	340	19	20260928	20	Filter Coffee	4	40.00	160.00	DELIVERED	CARD
ORD31CE0C859D	605	3	20260731	13	Butter Chicken	3	320.00	960.00	DELIVERED	UPI
ORD9D429497EF	421	9	20260930	12	Butter Naan	1	55.00	55.00	DELIVERED	COD
ORDDEEB72445B	7	17	20261009	13	Veg Biryani	2	220.00	440.00	DELIVERED	UPI
ORDE0C574E0C7	608	2	20260802	8	Veg Sushi Roll	2	350.00	700.00	DELIVERED	CARD
ORD11F0B1FB15	416	4	20260910	22	Margherita Pizza	2	299.00	598.00	DELIVERED	COD
ORD27561CA5CB	85	2	20260818	8	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD000494B802	450	9	20260918	20	Paneer Butter Masala	1	250.00	250.00	DELIVERED	COD
ORD8A1C7FD41C	38	9	20260903	21	Tandoori Chicken	1	340.00	340.00	DELIVERED	CARD
ORD118C50DE71	613	10	20260919	9	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORD15AEC2327F	392	9	20260914	14	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORD61E1B92559	283	6	20260723	13	Chicken Wrap	1	140.00	140.00	DELIVERED	CARD
ORDCBD5016570	218	3	20260804	14	Garlic Naan	1	60.00	60.00	DELIVERED	UPI
ORD774EEAD29C	286	6	20260729	12	French Fries	2	90.00	180.00	DELIVERED	UPI
ORD3BC532BA91	2	3	20261005	14	Garlic Naan	2	60.00	120.00	DELIVERED	UPI
ORDD4D3C86D22	56	2	20260828	8	Veg Sushi Roll	2	350.00	700.00	DELIVERED	UPI
ORD05502D7827	15	19	20260802	22	Masala Dosa	1	110.00	110.00	DELIVERED	UPI
ORD2697AD499B	421	2	20260717	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORDA8A91FF6A3	225	6	20260729	20	Chicken Wrap	2	140.00	280.00	DELIVERED	UPI
ORD54A5D60D82	622	9	20260719	8	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORD266EC038D3	557	4	20260827	13	Garlic Bread	4	120.00	480.00	PLACED	COD
ORD0B200ACDFD	494	9	20260717	22	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORD0637F2F3FE	149	2	20260827	19	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD1CE7FD768B	242	3	20260921	13	Paneer Tikka	2	260.00	520.00	DELIVERED	UPI
ORD6DE113DB05	578	10	20260909	19	Manchurian	1	210.00	210.00	DELIVERED	CARD
ORDE89ED4026E	46	9	20260724	12	Tandoori Chicken	3	340.00	1020.00	DELIVERED	CARD
ORD8EA8032EF1	6	6	20260902	17	Cheese Burger	2	150.00	300.00	DELIVERED	COD
ORD7F8D58074C	448	2	20260901	14	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD2934B6A03F	234	6	20260722	21	Cheese Burger	3	150.00	450.00	DELIVERED	UPI
ORDCE7944E9A7	48	10	20260917	21	Hakka Noodles	4	190.00	760.00	DELIVERED	UPI
ORDE13C91D207	296	10	20260725	17	Manchurian	4	210.00	840.00	DELIVERED	COD
ORD0B8A2899E8	27	3	20260929	20	Dal Makhani	4	220.00	880.00	CANCELLED	COD
ORD26C9088D95	635	17	20260730	22	Chicken Biryani	1	280.00	280.00	DELIVERED	CARD
ORDAAEB26083C	636	9	20260912	9	Butter Naan	1	55.00	55.00	DELIVERED	UPI
ORDE286DE88C7	534	17	20260805	20	Veg Biryani	2	220.00	440.00	DELIVERED	CARD
ORD7B08488A68	22	17	20260923	20	Raita	3	40.00	120.00	CANCELLED	UPI
ORD4802B214D1	456	9	20260822	14	Butter Naan	1	55.00	55.00	DELIVERED	UPI
ORDE51E22A86B	35	9	20260806	9	Tandoori Chicken	2	340.00	680.00	DELIVERED	COD
ORD70071CEC49	325	2	20260923	12	Veg Sushi Roll	1	350.00	350.00	DELIVERED	CARD
ORDC05AD2E89B	416	3	20260929	21	Paneer Tikka	4	260.00	1040.00	DELIVERED	COD
ORD79E3BDF0BA	181	9	20260825	21	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORDE285F534A7	37	2	20260819	13	Ramen Bowl	3	380.00	1140.00	DELIVERED	COD
ORD4012D5E3A9	411	10	20260826	14	Fried Rice	4	180.00	720.00	DELIVERED	COD
ORD702BE33FE0	646	2	20260829	22	Miso Soup	2	150.00	300.00	DELIVERED	COD
ORD628330857A	27	3	20260719	20	Garlic Naan	4	60.00	240.00	DELIVERED	COD
ORDB3EE41647F	284	4	20260901	9	Garlic Bread	2	120.00	240.00	DELIVERED	UPI
ORD4EC7D7937D	31	3	20260725	21	Paneer Tikka	1	260.00	260.00	DELIVERED	UPI
ORDAADD370A3A	295	2	20261002	12	Ramen Bowl	4	380.00	1520.00	DELIVERED	COD
ORD2F57409912	275	4	20261001	9	Margherita Pizza	3	299.00	897.00	DELIVERED	CARD
ORD5F9C9D7DB4	39	10	20261002	16	Fried Rice	4	180.00	720.00	PLACED	UPI
ORD7CF7D7994F	598	9	20260824	22	Paneer Butter Masala	1	250.00	250.00	DELIVERED	UPI
ORD9C85D91A20	654	9	20260921	9	Butter Naan	3	55.00	165.00	DELIVERED	COD
ORD479A01C78C	29	10	20260928	9	Fried Rice	2	180.00	360.00	DELIVERED	CARD
ORD63803CE529	434	6	20260729	14	Cheese Burger	4	150.00	600.00	DELIVERED	UPI
ORD9E1B048CF1	7	17	20260730	16	Veg Biryani	1	220.00	220.00	DELIVERED	UPI
ORDA2C397E6C5	425	17	20260905	21	Raita	2	40.00	80.00	DELIVERED	UPI
ORDB737447EE5	22	17	20260827	8	Veg Biryani	3	220.00	660.00	DELIVERED	UPI
ORD0A04AC8DF0	33	17	20260825	8	Chicken Biryani	1	280.00	280.00	CANCELLED	UPI
ORD2F2A22633F	661	6	20260904	19	Chicken Wrap	2	140.00	280.00	DELIVERED	CARD
ORDA1019E9F7D	662	3	20260908	9	Paneer Tikka	2	260.00	520.00	DELIVERED	UPI
ORD967D50F53B	104	9	20260830	19	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORD593499D5BF	515	2	20260928	20	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORDB0EF09D9C4	290	2	20260731	13	Veg Sushi Roll	2	350.00	700.00	DELIVERED	UPI
ORD10C7E39072	400	4	20260911	12	Margherita Pizza	1	299.00	299.00	DELIVERED	CARD
ORD0ED3606321	118	2	20260722	16	Veg Sushi Roll	2	350.00	700.00	DELIVERED	COD
ORD43A85C4100	406	10	20260915	20	Fried Rice	2	180.00	360.00	DELIVERED	UPI
ORD169C4AEE7F	12	10	20261004	16	Manchurian	3	210.00	630.00	CANCELLED	UPI
ORD7900F9FD5B	136	19	20260823	21	Filter Coffee	2	40.00	80.00	PLACED	CARD
ORD59D25CE156	32	9	20260922	19	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORDABF11F07FF	557	10	20260920	14	Hakka Noodles	2	190.00	380.00	DELIVERED	CARD
ORD8F2A985A55	326	9	20260827	19	Butter Naan	2	55.00	110.00	DELIVERED	UPI
ORD0E02341376	43	9	20260807	22	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORDE544BD7273	99	2	20260921	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	COD
ORDAA9C98CBA7	676	6	20260825	13	Cheese Burger	2	150.00	300.00	DELIVERED	UPI
ORD566AB6AF11	310	3	20261003	16	Paneer Tikka	1	260.00	260.00	DELIVERED	COD
ORDAE0642DE46	678	2	20260802	22	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	COD
ORDEAAC79FD4B	37	9	20260830	8	Tandoori Chicken	3	340.00	1020.00	DELIVERED	COD
ORD1A165BBD67	680	4	20261001	22	Pasta Alfredo	1	280.00	280.00	DELIVERED	CARD
ORD200DB44E45	42	9	20260803	20	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORDD22BEE193D	515	9	20261014	17	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORD888FFB219A	683	6	20261011	14	French Fries	1	90.00	90.00	DELIVERED	UPI
ORD8A0A6C7B34	684	2	20260920	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	COD
ORD47CB3BBFCA	29	10	20260828	17	Fried Rice	2	180.00	360.00	DELIVERED	COD
ORDC3E651DF57	77	6	20260724	9	Chicken Wrap	2	140.00	280.00	DELIVERED	UPI
ORD68961102B6	608	2	20260922	22	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORD23F661658E	30	17	20260802	22	Chicken Biryani	3	280.00	840.00	DELIVERED	CARD
ORD50809FA513	654	9	20260810	20	Tandoori Chicken	1	340.00	340.00	DELIVERED	COD
ORD1C92076922	89	17	20260918	13	Chicken Biryani	3	280.00	840.00	DELIVERED	UPI
ORD1EC29694EE	415	6	20260801	20	Cheese Burger	3	150.00	450.00	DELIVERED	CARD
ORD8D669A2C3F	468	9	20260907	20	Butter Naan	2	55.00	110.00	DELIVERED	COD
ORDFEA940738B	569	19	20260914	19	Idli Sambar	3	80.00	240.00	PLACED	COD
ORD57CF8C2871	243	2	20260723	12	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	COD
ORD8DF3C912F7	117	4	20260729	13	Margherita Pizza	2	299.00	598.00	DELIVERED	COD
ORD8AE6DE7D65	26	19	20261004	20	Idli Sambar	1	80.00	80.00	DELIVERED	COD
ORDE928A137B5	284	10	20260902	21	Fried Rice	2	180.00	360.00	DELIVERED	CARD
ORDE80AC6D76A	140	17	20260724	16	Veg Biryani	3	220.00	660.00	DELIVERED	UPI
ORD60FFF8D2AA	50	6	20260830	21	French Fries	1	90.00	90.00	DELIVERED	CARD
ORDB12DA5795A	701	3	20260817	14	Garlic Naan	4	60.00	240.00	DELIVERED	UPI
ORDEA959832DD	622	9	20260912	19	Butter Naan	3	55.00	165.00	DELIVERED	CARD
ORD7D41EFE079	269	6	20260920	16	Chicken Wrap	3	140.00	420.00	DELIVERED	UPI
ORDD33C368DF9	296	3	20261004	12	Paneer Tikka	3	260.00	780.00	DELIVERED	COD
ORD7AB329E7D6	32	2	20260718	9	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	UPI
ORD71CA719821	448	9	20261013	21	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORD3297E57B91	707	19	20260801	21	Filter Coffee	4	40.00	160.00	PLACED	CARD
ORD37FF392EFC	23	6	20261012	19	Cheese Burger	3	150.00	450.00	DELIVERED	COD
ORD09EAF75DCF	14	9	20260728	14	Tandoori Chicken	2	340.00	680.00	DELIVERED	UPI
ORD9B9CC9F4B9	710	9	20260923	22	Butter Naan	4	55.00	220.00	DELIVERED	UPI
ORD76B1603D75	711	19	20260908	9	Filter Coffee	3	40.00	120.00	DELIVERED	UPI
ORDEE2A22C87D	710	9	20260731	13	Paneer Butter Masala	3	250.00	750.00	DELIVERED	COD
ORDC2219B2F51	445	2	20260825	9	Miso Soup	2	150.00	300.00	DELIVERED	CARD
ORD65183A9E19	421	9	20260717	12	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORD6DC292D199	486	17	20260915	16	Veg Biryani	3	220.00	660.00	DELIVERED	COD
ORD3E75242D57	267	3	20260930	13	Garlic Naan	2	60.00	120.00	DELIVERED	COD
ORD298385F823	332	3	20260816	19	Dal Makhani	1	220.00	220.00	DELIVERED	UPI
ORDB4CA4B2803	379	17	20260922	8	Veg Biryani	3	220.00	660.00	DELIVERED	CARD
ORD7C8574CDEF	525	9	20260927	17	Butter Naan	2	55.00	110.00	DELIVERED	CARD
ORDE137D0FD6D	720	6	20260917	20	Cheese Burger	1	150.00	150.00	CANCELLED	UPI
ORDF1472C14DC	662	4	20260821	20	Garlic Bread	4	120.00	480.00	DELIVERED	UPI
ORDEAD39F19A1	722	9	20260930	9	Butter Naan	2	55.00	110.00	CANCELLED	COD
ORDA2625B9D71	215	2	20261008	21	Veg Sushi Roll	2	350.00	700.00	DELIVERED	UPI
ORD6F22B375B3	221	4	20261014	12	Pasta Alfredo	2	280.00	560.00	DELIVERED	CARD
ORD6354E5EDFC	441	10	20260905	19	Manchurian	1	210.00	210.00	DELIVERED	UPI
ORD3A0FC4044B	10	6	20260806	13	French Fries	2	90.00	180.00	DELIVERED	UPI
ORD053CEE6B66	168	6	20260822	12	French Fries	1	90.00	90.00	DELIVERED	UPI
ORDF348227393	420	2	20260920	21	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORD44FC80D16F	21	4	20260831	17	Garlic Bread	1	120.00	120.00	DELIVERED	COD
ORD7514B0A1E8	497	4	20260912	16	Garlic Bread	3	120.00	360.00	DELIVERED	UPI
ORD5223372F7C	288	10	20260910	9	Fried Rice	4	180.00	720.00	DELIVERED	UPI
ORD415659DFA2	71	9	20260918	19	Paneer Butter Masala	4	250.00	1000.00	CANCELLED	COD
ORDA3645A15AE	80	9	20261007	21	Paneer Butter Masala	1	250.00	250.00	DELIVERED	CARD
ORDC14722E1F9	326	9	20261008	9	Tandoori Chicken	2	340.00	680.00	CANCELLED	COD
ORD00B6F20F2B	11	9	20260812	13	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	CARD
ORD52210C9FC2	88	9	20260810	22	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	CARD
ORD16153FD51F	21	10	20260903	17	Fried Rice	1	180.00	180.00	DELIVERED	UPI
ORDD1AA5126F6	738	9	20261006	17	Butter Naan	4	55.00	220.00	PLACED	UPI
ORD1A7050DA52	378	2	20260918	20	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORDD09867B857	740	2	20260926	20	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORDCE4FC087BC	425	17	20260929	14	Veg Biryani	1	220.00	220.00	DELIVERED	COD
ORD784026497F	402	19	20260921	14	Masala Dosa	2	110.00	220.00	CANCELLED	UPI
ORDDBD07E5B36	22	17	20260909	13	Veg Biryani	4	220.00	880.00	DELIVERED	UPI
ORD59872C37AD	41	19	20260721	21	Filter Coffee	1	40.00	40.00	DELIVERED	UPI
ORDD1A09E6D87	66	9	20260730	21	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORD15273CE64F	181	2	20261010	13	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORDD341D44D7B	4	4	20261013	20	Pasta Alfredo	2	280.00	560.00	DELIVERED	COD
ORDD7568F054C	276	3	20260805	20	Paneer Tikka	3	260.00	780.00	CANCELLED	UPI
ORD7AABA0B687	453	6	20260914	20	Chicken Wrap	1	140.00	140.00	DELIVERED	COD
ORDA54BDA7358	121	10	20261007	9	Fried Rice	3	180.00	540.00	DELIVERED	CARD
ORD2010A342B7	231	19	20261007	21	Masala Dosa	1	110.00	110.00	DELIVERED	CARD
ORDFEA16DA4F0	752	9	20261014	17	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORD80FD7EE114	753	3	20261001	14	Dal Makhani	2	220.00	440.00	CANCELLED	CARD
ORD234528DA7E	754	9	20260730	9	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORDE4A10DC00F	755	2	20260921	8	Ramen Bowl	2	380.00	760.00	CANCELLED	UPI
ORD9C9533EBC0	180	9	20260729	13	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD4C5BE260E8	104	9	20260805	8	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORD27CE4682E0	54	9	20260730	13	Tandoori Chicken	4	340.00	1360.00	DELIVERED	CARD
ORD81D7263516	148	6	20260724	13	French Fries	3	90.00	270.00	DELIVERED	UPI
ORDCDF28AA950	144	3	20261001	21	Garlic Naan	3	60.00	180.00	DELIVERED	COD
ORDBE054C5DF7	406	4	20260815	20	Garlic Bread	2	120.00	240.00	DELIVERED	COD
ORD077F3364A9	179	4	20260905	16	Garlic Bread	3	120.00	360.00	DELIVERED	COD
ORDCD82BFCF89	394	19	20260826	16	Idli Sambar	4	80.00	320.00	DELIVERED	COD
ORD753DCD6FB0	296	4	20260807	21	Pasta Alfredo	2	280.00	560.00	DELIVERED	UPI
ORD6F2698B4D2	243	9	20260731	19	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORD6FAA7C2CEB	25	4	20260801	9	Margherita Pizza	1	299.00	299.00	DELIVERED	UPI
ORD67D981D2E4	227	19	20261010	14	Idli Sambar	2	80.00	160.00	DELIVERED	COD
ORD330B3D0D2C	468	9	20261011	20	Butter Naan	4	55.00	220.00	DELIVERED	CARD
ORDF8A8987BF7	720	17	20260727	14	Veg Biryani	2	220.00	440.00	DELIVERED	COD
ORDE197AAA286	770	10	20260918	21	Fried Rice	2	180.00	360.00	DELIVERED	CARD
ORD432E8BE5AA	160	3	20260809	12	Dal Makhani	4	220.00	880.00	DELIVERED	COD
ORD769299BC7B	165	9	20260728	21	Tandoori Chicken	2	340.00	680.00	CANCELLED	UPI
ORDE73136B356	162	2	20260721	21	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORD7E5D7900F0	26	17	20260827	20	Raita	3	40.00	120.00	DELIVERED	UPI
ORD49998C77D2	711	6	20260819	16	Chicken Wrap	2	140.00	280.00	DELIVERED	CARD
ORDC6F9587BE7	425	6	20260720	13	Cheese Burger	2	150.00	300.00	DELIVERED	CARD
ORD5934F04E52	777	4	20260918	13	Margherita Pizza	3	299.00	897.00	DELIVERED	CARD
ORDA9675A5AA9	778	2	20261008	22	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORD5EB16114B4	779	9	20260826	20	Tandoori Chicken	3	340.00	1020.00	DELIVERED	CARD
ORD6B17CDA851	45	19	20261002	21	Idli Sambar	3	80.00	240.00	DELIVERED	UPI
ORD87C785AAEE	234	6	20260810	20	Chicken Wrap	2	140.00	280.00	DELIVERED	CARD
ORD04CB97EFF0	487	6	20261002	21	Chicken Wrap	1	140.00	140.00	CANCELLED	COD
ORDEAC301E137	235	2	20260921	21	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORD4731BC4F41	148	17	20260915	19	Veg Biryani	3	220.00	660.00	DELIVERED	CARD
ORD34F71E3622	622	2	20260809	21	Ramen Bowl	1	380.00	380.00	DELIVERED	UPI
ORD5DDDFA977B	197	9	20260821	13	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORDA40C19805F	711	19	20260723	9	Idli Sambar	1	80.00	80.00	DELIVERED	COD
ORD3A46549E09	100	17	20260824	21	Raita	3	40.00	120.00	DELIVERED	COD
ORD4C26C4EFCD	451	2	20260929	21	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORDE588E384AD	790	17	20261002	17	Veg Biryani	3	220.00	660.00	DELIVERED	CARD
ORDD161A710C2	160	4	20260727	14	Pasta Alfredo	1	280.00	280.00	DELIVERED	CARD
ORD18D3B313FA	792	2	20260831	12	Veg Sushi Roll	1	350.00	350.00	CANCELLED	UPI
ORD9CA3714810	43	9	20260823	21	Tandoori Chicken	1	340.00	340.00	DELIVERED	CARD
ORD24ABF2D179	175	10	20260730	8	Manchurian	4	210.00	840.00	DELIVERED	COD
ORDB4FF7765F8	456	2	20260726	12	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORDC4B1B06578	148	17	20260823	16	Chicken Biryani	1	280.00	280.00	DELIVERED	UPI
ORD97BC003F5E	511	2	20260922	14	Miso Soup	4	150.00	600.00	DELIVERED	COD
ORD0DF3AABDFA	534	17	20260907	16	Raita	2	40.00	80.00	DELIVERED	CARD
ORD5A05CD4B45	799	9	20261006	22	Butter Naan	1	55.00	55.00	DELIVERED	UPI
ORDB305E1ED48	275	10	20260917	21	Fried Rice	4	180.00	720.00	DELIVERED	COD
ORDC93E1DFE83	497	3	20260827	21	Dal Makhani	1	220.00	220.00	DELIVERED	CARD
ORDBA2E116CD5	171	4	20260927	22	Pasta Alfredo	2	280.00	560.00	DELIVERED	UPI
ORD2F37DF131C	803	2	20260720	9	Veg Sushi Roll	1	350.00	350.00	DELIVERED	COD
ORD0DFA2AE610	98	10	20260813	22	Manchurian	2	210.00	420.00	DELIVERED	UPI
ORD748DD18A0E	676	19	20260819	21	Idli Sambar	3	80.00	240.00	DELIVERED	CARD
ORDBBCD92B390	754	2	20260821	21	Miso Soup	1	150.00	150.00	DELIVERED	COD
ORDF455DF7C53	127	3	20260902	17	Butter Chicken	4	320.00	1280.00	DELIVERED	CARD
ORD5394BD7026	183	3	20260815	21	Paneer Tikka	2	260.00	520.00	DELIVERED	CARD
ORD43759661D2	809	6	20260820	21	Cheese Burger	4	150.00	600.00	CANCELLED	UPI
ORD4A62AF883D	661	19	20260720	12	Filter Coffee	4	40.00	160.00	DELIVERED	CARD
ORD5F6C80FED8	811	2	20260830	8	Ramen Bowl	3	380.00	1140.00	DELIVERED	CARD
ORDBD2D85F911	346	6	20260926	21	Cheese Burger	3	150.00	450.00	DELIVERED	UPI
ORDA575B16B73	126	9	20260919	21	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORD37D1EDB900	487	6	20261006	13	Chicken Wrap	1	140.00	140.00	DELIVERED	UPI
ORD41F31AA5FE	276	3	20261002	22	Dal Makhani	3	220.00	660.00	DELIVERED	CARD
ORD0BDD534EE2	816	9	20260821	9	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORDF99183E717	57	2	20260805	22	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORDFF18756410	103	4	20260901	21	Pasta Alfredo	1	280.00	280.00	DELIVERED	CARD
ORDAA2A42F5C4	170	2	20260729	17	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORD458F5FAD4E	654	2	20260826	17	Miso Soup	3	150.00	450.00	DELIVERED	COD
ORD4FBBD2FDB5	487	19	20260912	14	Masala Dosa	1	110.00	110.00	DELIVERED	UPI
ORD7131AA8D97	265	2	20260905	22	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORDC76B6E2E57	205	9	20260807	20	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORDE81871B91F	803	2	20260719	21	Miso Soup	3	150.00	450.00	DELIVERED	CARD
ORDA86C9E9FF6	151	10	20260913	16	Manchurian	2	210.00	420.00	DELIVERED	UPI
ORD81516B1002	179	10	20260829	20	Manchurian	1	210.00	210.00	DELIVERED	COD
ORDB5FA5F8566	210	3	20260805	21	Dal Makhani	4	220.00	880.00	DELIVERED	UPI
ORD4FEA53E518	42	2	20260817	13	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	COD
ORDFF6856E6D1	829	2	20260926	12	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD86A0E43882	218	4	20260824	12	Pasta Alfredo	4	280.00	1120.00	DELIVERED	UPI
ORDA648CBA573	14	9	20260813	22	Paneer Butter Masala	2	250.00	500.00	DELIVERED	COD
ORD155D6F5735	661	17	20260923	19	Raita	2	40.00	80.00	DELIVERED	UPI
ORD799F85D5D3	89	6	20260831	14	Chicken Wrap	3	140.00	420.00	DELIVERED	UPI
ORD901EA44EE0	494	9	20260910	16	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORDCB75A4C34A	79	2	20260726	19	Ramen Bowl	1	380.00	380.00	DELIVERED	CARD
ORD3B0383B00D	329	17	20260922	14	Chicken Biryani	4	280.00	1120.00	DELIVERED	UPI
ORDEFBC75B4B5	8	17	20260722	13	Raita	1	40.00	40.00	DELIVERED	CARD
ORDF43670B477	430	9	20260723	20	Tandoori Chicken	2	340.00	680.00	DELIVERED	CARD
ORD511626FC3B	156	2	20260916	22	Miso Soup	2	150.00	300.00	DELIVERED	CARD
ORD797ECC98A6	840	6	20260809	13	Chicken Wrap	2	140.00	280.00	DELIVERED	CARD
ORD3869B187BE	203	9	20260916	19	Paneer Butter Masala	3	250.00	750.00	CANCELLED	COD
ORD0E5389667A	2	4	20261008	9	Pasta Alfredo	3	280.00	840.00	CANCELLED	UPI
ORD2C2F1FDF69	843	9	20260830	20	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORDF7BD40164A	447	9	20260918	16	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORDB7BED73D15	11	9	20260808	16	Butter Naan	1	55.00	55.00	DELIVERED	CARD
ORDA370E47214	561	17	20261008	17	Veg Biryani	1	220.00	220.00	DELIVERED	COD
ORDA8E7F5CFBA	70	2	20261010	17	Miso Soup	3	150.00	450.00	DELIVERED	CARD
ORD1EE130C934	587	17	20260820	8	Chicken Biryani	1	280.00	280.00	DELIVERED	UPI
ORDF1168A38BB	119	2	20260813	19	Miso Soup	3	150.00	450.00	DELIVERED	UPI
ORD015EFB3060	850	3	20261004	8	Butter Chicken	3	320.00	960.00	DELIVERED	UPI
ORD40AF669F5F	79	2	20260914	8	Veg Sushi Roll	2	350.00	700.00	DELIVERED	COD
ORD8E4FAF5BAF	770	4	20260730	16	Margherita Pizza	4	299.00	1196.00	DELIVERED	UPI
ORDBFB599D8C7	254	2	20260820	13	Ramen Bowl	3	380.00	1140.00	DELIVERED	CARD
ORD5BB6879D37	89	17	20260809	19	Raita	4	40.00	160.00	DELIVERED	COD
ORDCD20765BC7	194	3	20261012	14	Dal Makhani	4	220.00	880.00	CANCELLED	UPI
ORD6E5EEA4E86	856	19	20260814	20	Masala Dosa	4	110.00	440.00	DELIVERED	UPI
ORDC9C2127FDC	360	19	20260830	21	Idli Sambar	3	80.00	240.00	DELIVERED	UPI
ORD156027CAD6	341	4	20260826	17	Garlic Bread	1	120.00	120.00	DELIVERED	UPI
ORDD437DF4CB0	235	9	20260730	17	Paneer Butter Masala	1	250.00	250.00	DELIVERED	UPI
ORDF459BB1014	231	19	20260827	8	Idli Sambar	1	80.00	80.00	CANCELLED	CARD
ORD3EF0D0A0D2	48	10	20260917	14	Fried Rice	1	180.00	180.00	DELIVERED	CARD
ORDB090ED137F	89	17	20261010	13	Chicken Biryani	2	280.00	560.00	DELIVERED	UPI
ORDE294E2F958	203	2	20260911	8	Ramen Bowl	1	380.00	380.00	DELIVERED	UPI
ORD8B9DB027A0	216	17	20260817	21	Raita	4	40.00	160.00	DELIVERED	UPI
ORD4EDC0D058E	180	2	20260913	14	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	UPI
ORD7C3C56BC74	515	2	20260904	16	Miso Soup	3	150.00	450.00	DELIVERED	UPI
ORD3A299D4FAD	77	19	20260723	20	Idli Sambar	4	80.00	320.00	DELIVERED	UPI
ORDFC64F0B375	535	4	20260813	19	Pasta Alfredo	2	280.00	560.00	DELIVERED	CARD
ORD42D03AD536	869	2	20260919	21	Ramen Bowl	4	380.00	1520.00	DELIVERED	COD
ORD5D32B402F6	415	19	20261010	20	Filter Coffee	2	40.00	80.00	PLACED	COD
ORD3A331473DD	871	9	20260901	17	Tandoori Chicken	1	340.00	340.00	DELIVERED	CARD
ORD464BD6B36F	635	6	20260919	22	Chicken Wrap	2	140.00	280.00	DELIVERED	UPI
ORD306803D2D4	2	10	20261010	17	Fried Rice	3	180.00	540.00	DELIVERED	CARD
ORD1DB03736F7	874	4	20260816	14	Pasta Alfredo	1	280.00	280.00	DELIVERED	UPI
ORDE10A675F6C	130	2	20260824	21	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD88A02EC3D4	27	4	20260928	21	Margherita Pizza	1	299.00	299.00	DELIVERED	UPI
ORD9562C3296C	56	9	20260814	19	Butter Naan	4	55.00	220.00	CANCELLED	CARD
ORD94D6B9EEB7	654	2	20260901	17	Miso Soup	4	150.00	600.00	DELIVERED	CARD
ORD931C00DB7E	295	9	20260817	21	Tandoori Chicken	3	340.00	1020.00	DELIVERED	COD
ORDD051E7496E	880	2	20260903	20	Miso Soup	3	150.00	450.00	DELIVERED	UPI
ORDC1A20F0CB6	2	3	20260830	8	Garlic Naan	4	60.00	240.00	DELIVERED	CARD
ORDD2B22A7889	289	3	20260904	13	Butter Chicken	4	320.00	1280.00	DELIVERED	CARD
ORD2AC76B4008	467	10	20260920	19	Hakka Noodles	3	190.00	570.00	DELIVERED	UPI
ORD21B2B756A0	884	9	20261008	13	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORD7FA2C3DB34	362	9	20260827	14	Tandoori Chicken	1	340.00	340.00	DELIVERED	COD
ORD68A96B6989	165	2	20260923	14	Ramen Bowl	1	380.00	380.00	DELIVERED	CARD
ORD962BB9C2FD	313	3	20260909	16	Paneer Tikka	3	260.00	780.00	DELIVERED	CARD
ORD465D5E8486	198	3	20260822	12	Butter Chicken	1	320.00	320.00	DELIVERED	COD
ORDE342585FE4	85	9	20260806	17	Paneer Butter Masala	1	250.00	250.00	DELIVERED	COD
ORDC8AFACDCBF	662	3	20260727	13	Dal Makhani	4	220.00	880.00	DELIVERED	COD
ORD6FC108BEC5	891	9	20260921	22	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	CARD
ORD95C4BDA9F0	55	17	20260917	13	Raita	3	40.00	120.00	DELIVERED	COD
ORDBD38A8296C	197	2	20260818	13	Miso Soup	4	150.00	600.00	DELIVERED	CARD
ORD766F878D92	151	4	20261006	21	Margherita Pizza	1	299.00	299.00	DELIVERED	COD
ORDABB4EE1EC4	895	9	20260910	19	Paneer Butter Masala	2	250.00	500.00	DELIVERED	COD
ORDECDBB88E45	147	6	20261003	20	Cheese Burger	3	150.00	450.00	DELIVERED	CARD
ORDFFCD82E1A1	55	17	20260817	21	Raita	2	40.00	80.00	DELIVERED	UPI
ORD1D60C4D915	107	9	20260902	21	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORDB72CEC9ED8	711	19	20260818	19	Idli Sambar	1	80.00	80.00	DELIVERED	CARD
ORD990EBB9698	29	3	20261009	20	Paneer Tikka	3	260.00	780.00	CANCELLED	UPI
ORDC3B6E1F197	54	2	20260820	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	CARD
ORD06676AF1AE	778	9	20260921	20	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORDFCE1D94B2A	317	17	20260821	21	Veg Biryani	2	220.00	440.00	DELIVERED	COD
ORD75F1BDADEA	904	4	20260917	22	Margherita Pizza	2	299.00	598.00	DELIVERED	UPI
ORDAF16440C77	7	19	20261004	19	Masala Dosa	2	110.00	220.00	DELIVERED	UPI
ORD109B97C8D7	840	17	20261009	20	Veg Biryani	3	220.00	660.00	PLACED	CARD
ORDF17B4F47AA	505	6	20261004	13	Chicken Wrap	1	140.00	140.00	DELIVERED	UPI
ORD90F8BAEC52	908	4	20261010	21	Garlic Bread	2	120.00	240.00	DELIVERED	UPI
ORD39C88C22C7	49	10	20260912	16	Fried Rice	3	180.00	540.00	DELIVERED	UPI
ORDDCF79E6AF7	895	2	20261002	20	Veg Sushi Roll	1	350.00	350.00	DELIVERED	COD
ORD51FBF1075B	170	9	20260925	22	Butter Naan	1	55.00	55.00	DELIVERED	COD
ORD2D5C88EEED	445	2	20260926	12	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORDA23F1AB1C6	72	3	20260814	14	Paneer Tikka	3	260.00	780.00	DELIVERED	UPI
ORDB15284EC62	232	6	20260803	20	Cheese Burger	4	150.00	600.00	DELIVERED	COD
ORD978DCE907E	34	4	20260725	12	Garlic Bread	1	120.00	120.00	DELIVERED	COD
ORD39EE710187	221	3	20261010	12	Dal Makhani	3	220.00	660.00	DELIVERED	UPI
ORD0A6876B269	662	3	20261014	13	Garlic Naan	3	60.00	180.00	DELIVERED	CARD
ORDF29569C08C	22	17	20260721	17	Veg Biryani	3	220.00	660.00	DELIVERED	COD
ORD71D10806C1	57	9	20260814	19	Tandoori Chicken	3	340.00	1020.00	DELIVERED	COD
ORD8E39E6479C	37	9	20260825	20	Paneer Butter Masala	1	250.00	250.00	DELIVERED	COD
ORD23C4AE67D0	204	9	20260916	12	Paneer Butter Masala	3	250.00	750.00	DELIVERED	COD
ORD9052490BCE	243	9	20260807	12	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORD012D8D4120	88	2	20260810	8	Ramen Bowl	1	380.00	380.00	DELIVERED	COD
ORDF4F2066CE4	474	19	20261013	20	Filter Coffee	3	40.00	120.00	DELIVERED	UPI
ORD0A2F30B02C	93	19	20260818	19	Idli Sambar	1	80.00	80.00	DELIVERED	UPI
ORDBC722FB088	258	10	20260909	13	Hakka Noodles	1	190.00	190.00	DELIVERED	CARD
ORDEF44303CBC	127	3	20260813	16	Dal Makhani	2	220.00	440.00	DELIVERED	UPI
ORDB404A8169B	755	9	20260910	9	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORDF7A1D63C06	588	17	20260818	17	Veg Biryani	3	220.00	660.00	DELIVERED	CARD
ORD751524C84E	562	9	20261008	14	Tandoori Chicken	3	340.00	1020.00	CANCELLED	UPI
ORDCB7380EDDF	181	2	20260914	14	Veg Sushi Roll	1	350.00	350.00	PLACED	UPI
ORDA5522A51D8	219	2	20260918	16	Miso Soup	1	150.00	150.00	DELIVERED	COD
ORDED3B68DA69	35	2	20261007	17	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORDA7D02E6E80	934	19	20261005	22	Masala Dosa	3	110.00	330.00	DELIVERED	COD
ORD79A1E41F3E	171	4	20260802	14	Margherita Pizza	4	299.00	1196.00	DELIVERED	UPI
ORD24DDF8D277	415	6	20260805	13	Cheese Burger	4	150.00	600.00	DELIVERED	UPI
ORD43C4B63399	527	17	20260729	20	Veg Biryani	3	220.00	660.00	DELIVERED	UPI
ORD20FB62FF35	17	3	20260720	13	Garlic Naan	1	60.00	60.00	DELIVERED	UPI
ORD0F97639465	153	4	20260806	14	Margherita Pizza	3	299.00	897.00	DELIVERED	CARD
ORD40FDD4C9DC	710	9	20260907	9	Paneer Butter Masala	1	250.00	250.00	DELIVERED	UPI
ORD1DBB9666D9	504	4	20260925	17	Garlic Bread	1	120.00	120.00	DELIVERED	COD
ORD668B661F60	253	2	20260919	13	Miso Soup	3	150.00	450.00	DELIVERED	COD
ORD84AC5898FF	754	9	20260814	8	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORD45B659484F	57	9	20260729	12	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORD075BF30DC4	28	19	20260929	21	Idli Sambar	1	80.00	80.00	DELIVERED	CARD
ORDD411DAC307	102	3	20260816	20	Butter Chicken	1	320.00	320.00	DELIVERED	COD
ORDCCEA044091	298	17	20260922	21	Chicken Biryani	1	280.00	280.00	DELIVERED	UPI
ORD47949BAE2F	265	2	20260922	22	Ramen Bowl	4	380.00	1520.00	DELIVERED	CARD
ORD33490C594F	45	6	20261001	17	Chicken Wrap	2	140.00	280.00	CANCELLED	COD
ORDE6F9FBC61A	608	2	20260827	13	Ramen Bowl	3	380.00	1140.00	DELIVERED	CARD
ORD17A50F36EA	951	6	20260719	9	Cheese Burger	2	150.00	300.00	DELIVERED	COD
ORDA5DF85DACC	329	17	20261007	21	Chicken Biryani	4	280.00	1120.00	DELIVERED	UPI
ORDFE6B8B04B8	635	6	20260912	9	Chicken Wrap	4	140.00	560.00	DELIVERED	COD
ORDFFAAE84580	179	4	20261007	13	Margherita Pizza	3	299.00	897.00	DELIVERED	UPI
ORDAE59B734DF	233	9	20260901	22	Tandoori Chicken	3	340.00	1020.00	DELIVERED	CARD
ORD842616A6BD	662	3	20260911	13	Garlic Naan	3	60.00	180.00	DELIVERED	UPI
ORD242CB92D6A	843	2	20260719	20	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	UPI
ORDC2943EA522	420	9	20260914	21	Paneer Butter Masala	3	250.00	750.00	DELIVERED	COD
ORD30ACED223C	171	10	20261001	13	Manchurian	4	210.00	840.00	DELIVERED	CARD
ORDF9E14D4468	19	9	20261007	12	Tandoori Chicken	1	340.00	340.00	DELIVERED	COD
ORDE047C498B3	119	9	20260725	8	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORD16BB5E0606	329	17	20260804	14	Chicken Biryani	4	280.00	1120.00	DELIVERED	COD
ORD650763E3EA	229	9	20260825	13	Butter Naan	3	55.00	165.00	DELIVERED	UPI
ORD15C097ABAE	352	9	20260911	13	Butter Naan	4	55.00	220.00	DELIVERED	UPI
ORD46046BCD31	26	19	20260925	9	Filter Coffee	1	40.00	40.00	DELIVERED	COD
ORDCD01D435BE	966	4	20260926	17	Margherita Pizza	2	299.00	598.00	DELIVERED	UPI
ORD60B74C09CB	967	9	20261007	19	Paneer Butter Masala	3	250.00	750.00	DELIVERED	CARD
ORD968234B72C	622	2	20260814	20	Miso Soup	3	150.00	450.00	CANCELLED	UPI
ORDA67D63B008	486	6	20261003	14	Cheese Burger	4	150.00	600.00	DELIVERED	CARD
ORD73BF55CE5C	970	6	20260722	22	Cheese Burger	4	150.00	600.00	CANCELLED	COD
ORD2EF9957337	497	4	20260829	13	Pasta Alfredo	1	280.00	280.00	DELIVERED	COD
ORD94B1D5B2DB	170	2	20260927	14	Miso Soup	3	150.00	450.00	DELIVERED	UPI
ORDDEFF8F1651	93	19	20261001	8	Idli Sambar	1	80.00	80.00	DELIVERED	COD
ORDD81CF69A80	128	2	20260804	20	Miso Soup	1	150.00	150.00	CANCELLED	CARD
ORDC25ACB27EE	320	6	20260808	17	Chicken Wrap	2	140.00	280.00	DELIVERED	UPI
ORD85ACE9C35B	352	2	20260823	19	Ramen Bowl	4	380.00	1520.00	DELIVERED	UPI
ORDE120FE7453	151	4	20260908	9	Garlic Bread	1	120.00	120.00	DELIVERED	COD
ORD1F20427A31	970	19	20260803	22	Masala Dosa	4	110.00	440.00	DELIVERED	UPI
ORD3C32457BFC	146	17	20260817	17	Veg Biryani	2	220.00	440.00	DELIVERED	COD
ORDD838345C69	108	17	20260826	21	Veg Biryani	2	220.00	440.00	DELIVERED	UPI
ORDB5BB71D166	160	3	20260721	8	Garlic Naan	4	60.00	240.00	DELIVERED	CARD
ORDBCDD1F297C	754	2	20260910	13	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORDA3ADBC9309	114	9	20260825	13	Tandoori Chicken	2	340.00	680.00	DELIVERED	CARD
ORD28E842AA24	779	2	20260730	20	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORDE859889586	229	2	20260810	16	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	UPI
ORD63427E73F9	18	6	20261013	17	French Fries	2	90.00	180.00	DELIVERED	UPI
ORD5156931665	580	3	20260816	8	Garlic Naan	4	60.00	240.00	DELIVERED	COD
ORDB33F45205B	112	6	20260723	12	Cheese Burger	4	150.00	600.00	DELIVERED	CARD
ORDAA048CDEBE	134	19	20260921	9	Idli Sambar	1	80.00	80.00	DELIVERED	COD
ORDD19F44FE0F	811	9	20260810	9	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORD18FF84C7F4	33	19	20260730	13	Filter Coffee	4	40.00	160.00	CANCELLED	UPI
ORDC2310D908F	430	2	20261012	12	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORD5FC007E65C	12	3	20260921	9	Dal Makhani	2	220.00	440.00	DELIVERED	COD
ORDB75AF60747	994	3	20261001	17	Butter Chicken	4	320.00	1280.00	DELIVERED	CARD
ORDC301D93B84	196	9	20260925	8	Butter Naan	4	55.00	220.00	DELIVERED	UPI
ORD9430920AB8	532	17	20260727	16	Veg Biryani	1	220.00	220.00	DELIVERED	CARD
ORD2C47D5BDCE	680	4	20260827	8	Pasta Alfredo	2	280.00	560.00	DELIVERED	COD
ORDE88878945D	162	2	20260721	9	Miso Soup	2	150.00	300.00	DELIVERED	CARD
ORDF160A7BC40	320	17	20260728	8	Veg Biryani	4	220.00	880.00	DELIVERED	COD
ORD627AAF7EB0	101	10	20260907	22	Manchurian	4	210.00	840.00	DELIVERED	COD
ORDBD6F8488A3	144	3	20260915	13	Dal Makhani	3	220.00	660.00	DELIVERED	CARD
ORD457391CE85	184	4	20260822	8	Garlic Bread	4	120.00	480.00	DELIVERED	COD
ORD5F22CCE99E	994	3	20260930	20	Dal Makhani	3	220.00	660.00	DELIVERED	COD
ORD0333E19AFE	92	9	20260801	8	Tandoori Chicken	3	340.00	1020.00	DELIVERED	CARD
ORD6F1F4CDA68	5	6	20260718	13	Chicken Wrap	1	140.00	140.00	DELIVERED	COD
ORDCD35510D4C	398	9	20260915	17	Paneer Butter Masala	4	250.00	1000.00	DELIVERED	UPI
ORD8865E16306	283	17	20260904	12	Veg Biryani	2	220.00	440.00	DELIVERED	UPI
ORD21ED396007	486	17	20261011	13	Veg Biryani	4	220.00	880.00	DELIVERED	CARD
ORD4E1D92FE12	770	3	20260723	14	Dal Makhani	4	220.00	880.00	DELIVERED	UPI
ORDD06B01CED2	38	9	20260823	20	Butter Naan	3	55.00	165.00	PLACED	UPI
ORD5FD8D759E0	60	9	20260920	21	Butter Naan	2	55.00	110.00	DELIVERED	COD
ORD7C126DD051	720	19	20260721	21	Filter Coffee	1	40.00	40.00	DELIVERED	UPI
ORD342DB4D90B	46	2	20260816	16	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORD76F6CFE1B9	497	4	20260905	19	Pasta Alfredo	1	280.00	280.00	DELIVERED	UPI
ORDE18B9CE49F	777	4	20260930	17	Pasta Alfredo	3	280.00	840.00	DELIVERED	UPI
ORD4173CC0A30	46	2	20260720	8	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORD81B31F26F0	408	2	20260815	21	Ramen Bowl	4	380.00	1520.00	CANCELLED	COD
ORDE532485C07	369	6	20260813	22	French Fries	3	90.00	270.00	DELIVERED	UPI
ORDDA8BA30CDD	26	19	20261009	17	Masala Dosa	2	110.00	220.00	DELIVERED	UPI
ORDCFE40CFBB5	352	9	20260813	12	Butter Naan	3	55.00	165.00	DELIVERED	CARD
ORD3747DC5780	356	2	20260811	16	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORD064D03E271	497	3	20260828	13	Dal Makhani	4	220.00	880.00	DELIVERED	UPI
ORDA5B8AC90A7	28	19	20260726	21	Masala Dosa	3	110.00	330.00	DELIVERED	UPI
ORD08E2D4FEA2	215	9	20261004	19	Tandoori Chicken	4	340.00	1360.00	DELIVERED	CARD
ORDBF2593A134	42	2	20260910	17	Veg Sushi Roll	2	350.00	700.00	DELIVERED	CARD
ORD87581FCD4D	474	6	20260913	9	Cheese Burger	4	150.00	600.00	CANCELLED	CARD
ORD3FB33E122C	76	2	20260719	8	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORD1701D2F3DB	31	10	20260811	20	Manchurian	1	210.00	210.00	DELIVERED	CARD
ORD87F568F475	1029	4	20260913	12	Garlic Bread	3	120.00	360.00	DELIVERED	UPI
ORD6C78907270	371	2	20260828	20	Miso Soup	1	150.00	150.00	DELIVERED	CARD
ORD0617C15A37	701	10	20260930	13	Fried Rice	2	180.00	360.00	DELIVERED	CARD
ORDCE8966B7D2	356	9	20260922	9	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORDD06A14BCA6	398	2	20260726	17	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	UPI
ORD48EA464224	951	17	20260816	21	Chicken Biryani	2	280.00	560.00	CANCELLED	UPI
ORDCAF6AA03F4	527	17	20260729	13	Veg Biryani	2	220.00	440.00	DELIVERED	UPI
ORD9968190923	126	9	20260923	21	Paneer Butter Masala	1	250.00	250.00	DELIVERED	COD
ORD144A03498A	174	10	20260924	22	Hakka Noodles	1	190.00	190.00	DELIVERED	COD
ORDB3E1F601C4	80	2	20260913	9	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORD17D740F57C	515	9	20260717	21	Tandoori Chicken	1	340.00	340.00	DELIVERED	COD
ORD4FD5A11565	216	19	20260914	17	Idli Sambar	4	80.00	320.00	DELIVERED	UPI
ORDADC723C06C	494	9	20260919	21	Tandoori Chicken	1	340.00	340.00	DELIVERED	UPI
ORDCD0374B1B4	752	9	20260721	20	Butter Naan	2	55.00	110.00	DELIVERED	COD
ORD538A1EAAA0	317	19	20260806	9	Filter Coffee	4	40.00	160.00	DELIVERED	COD
ORDAB8304B080	646	9	20260726	12	Paneer Butter Masala	1	250.00	250.00	DELIVERED	UPI
ORDC5AC4B9C2D	23	19	20260901	17	Idli Sambar	3	80.00	240.00	DELIVERED	CARD
ORDF6F6D69C13	531	2	20260728	12	Veg Sushi Roll	4	350.00	1400.00	DELIVERED	UPI
ORDAB5872343A	99	2	20260827	16	Ramen Bowl	3	380.00	1140.00	DELIVERED	CARD
ORDB070A0F2D8	10	6	20260809	9	French Fries	1	90.00	90.00	DELIVERED	UPI
ORD0DBACF3B4F	233	9	20260728	8	Paneer Butter Masala	2	250.00	500.00	DELIVERED	UPI
ORD836D71BF99	346	6	20260726	20	Chicken Wrap	4	140.00	560.00	DELIVERED	UPI
ORD914C0706AA	1051	17	20260930	21	Veg Biryani	3	220.00	660.00	DELIVERED	UPI
ORD1E3F707654	346	6	20260901	13	French Fries	2	90.00	180.00	DELIVERED	UPI
ORD7E7724B8C6	204	2	20260918	13	Ramen Bowl	1	380.00	380.00	DELIVERED	UPI
ORDBC26E51201	777	10	20260817	20	Hakka Noodles	2	190.00	380.00	DELIVERED	UPI
ORD863E3F3E6C	102	10	20260724	13	Manchurian	2	210.00	420.00	DELIVERED	UPI
ORD45F2792144	1056	4	20260720	9	Pasta Alfredo	4	280.00	1120.00	DELIVERED	COD
ORD432B76EBDB	198	10	20261003	20	Hakka Noodles	1	190.00	190.00	DELIVERED	COD
ORDF2460383E5	636	2	20260811	20	Ramen Bowl	3	380.00	1140.00	DELIVERED	COD
ORD078A3C4F64	480	2	20260719	17	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	UPI
ORD1F3204FADC	676	17	20260922	12	Raita	3	40.00	120.00	CANCELLED	CARD
ORDBE89269A21	317	17	20260911	20	Raita	4	40.00	160.00	DELIVERED	COD
ORD7D7C8C1269	160	4	20260901	17	Pasta Alfredo	2	280.00	560.00	DELIVERED	UPI
ORD1456E2D791	88	2	20260725	19	Miso Soup	4	150.00	600.00	DELIVERED	UPI
ORDC5C6905300	5	6	20261010	13	Chicken Wrap	2	140.00	280.00	DELIVERED	CARD
ORDC551C97F8B	235	2	20261014	14	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD35088072A4	1066	6	20260803	8	Chicken Wrap	3	140.00	420.00	DELIVERED	CARD
ORD40ACD6D0E5	770	4	20260910	20	Pasta Alfredo	4	280.00	1120.00	DELIVERED	COD
ORDADEEBC3AA0	104	2	20261013	20	Miso Soup	3	150.00	450.00	DELIVERED	COD
ORDAE2AC1C407	183	10	20260822	8	Fried Rice	1	180.00	180.00	DELIVERED	COD
ORDBB8BF37548	234	17	20260907	12	Veg Biryani	3	220.00	660.00	DELIVERED	CARD
ORDC0F1CDAE55	182	4	20260717	19	Pasta Alfredo	2	280.00	560.00	DELIVERED	UPI
ORD8E067E2ECE	840	17	20260729	13	Raita	2	40.00	80.00	DELIVERED	COD
ORD4949C34F98	425	17	20260815	19	Chicken Biryani	2	280.00	560.00	DELIVERED	CARD
ORD424F0D6D88	504	3	20260913	14	Dal Makhani	3	220.00	660.00	CANCELLED	CARD
ORD43A2883AA7	317	6	20260727	20	French Fries	4	90.00	360.00	DELIVERED	UPI
ORDDA758C4010	1076	9	20260719	22	Tandoori Chicken	1	340.00	340.00	DELIVERED	CARD
ORD44AD770DF0	14	2	20260720	16	Ramen Bowl	3	380.00	1140.00	DELIVERED	UPI
ORD932AE32DA6	456	2	20260811	21	Ramen Bowl	2	380.00	760.00	DELIVERED	UPI
ORD445717478C	54	2	20260820	19	Miso Soup	1	150.00	150.00	DELIVERED	COD
ORD0F1ACC6752	127	3	20260926	21	Dal Makhani	2	220.00	440.00	DELIVERED	UPI
ORDB32240BC22	1081	4	20260926	16	Pasta Alfredo	1	280.00	280.00	DELIVERED	UPI
ORD42BE8DC97F	229	2	20260829	19	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORDAE5EC651D5	90	9	20260926	20	Butter Naan	4	55.00	220.00	DELIVERED	CARD
ORDC2A737A55C	102	10	20260831	21	Hakka Noodles	4	190.00	760.00	DELIVERED	UPI
ORDF57A7E9757	443	2	20261005	8	Miso Soup	3	150.00	450.00	DELIVERED	COD
ORDB55EC1765A	578	10	20260929	14	Hakka Noodles	1	190.00	190.00	DELIVERED	UPI
ORD56971B824E	1029	4	20260725	21	Pasta Alfredo	4	280.00	1120.00	DELIVERED	CARD
ORD70D403E095	535	3	20260924	14	Garlic Naan	2	60.00	120.00	DELIVERED	UPI
ORDDDD62AF8A5	225	6	20260910	20	Cheese Burger	4	150.00	600.00	DELIVERED	UPI
ORD14272B4904	48	3	20260731	16	Garlic Naan	1	60.00	60.00	DELIVERED	CARD
ORDD14A8303AA	102	10	20260918	21	Hakka Noodles	4	190.00	760.00	DELIVERED	UPI
ORDC150F5108F	738	9	20260816	21	Paneer Butter Masala	3	250.00	750.00	DELIVERED	UPI
ORD3A5BC1B066	354	9	20260828	13	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORD1C9F2846A0	340	17	20261011	13	Raita	4	40.00	160.00	DELIVERED	UPI
ORDF595EC4781	356	2	20260929	17	Veg Sushi Roll	3	350.00	1050.00	DELIVERED	COD
ORD00B8D6B3D0	755	9	20260729	21	Paneer Butter Masala	1	250.00	250.00	DELIVERED	UPI
ORDC25246D6F5	816	2	20260717	13	Miso Soup	1	150.00	150.00	DELIVERED	UPI
ORDF3084B480F	231	19	20260919	12	Filter Coffee	2	40.00	80.00	DELIVERED	UPI
ORDF70BACC96F	1099	2	20260815	13	Veg Sushi Roll	1	350.00	350.00	DELIVERED	UPI
ORD2845D7D041	215	9	20260718	20	Tandoori Chicken	4	340.00	1360.00	DELIVERED	CARD
ORD51E210756C	420	2	20260923	16	Miso Soup	1	150.00	150.00	DELIVERED	COD
ORD05D1E87830	255	19	20260804	16	Filter Coffee	4	40.00	160.00	CANCELLED	COD
ORD7CEC14E786	613	3	20260928	13	Garlic Naan	1	60.00	60.00	PLACED	CARD
ORD546F4444F4	59	3	20260830	8	Garlic Naan	1	60.00	60.00	DELIVERED	COD
ORD51D3010139	120	9	20260911	20	Butter Naan	3	55.00	165.00	DELIVERED	CARD
ORDEBCE1D5636	182	3	20260830	13	Paneer Tikka	2	260.00	520.00	DELIVERED	UPI
ORD0BC45636A6	753	10	20260804	21	Fried Rice	4	180.00	720.00	DELIVERED	COD
ORD3A9EE497CD	531	2	20260816	9	Ramen Bowl	1	380.00	380.00	DELIVERED	CARD
ORDB5D98DA23A	57	9	20261007	20	Tandoori Chicken	3	340.00	1020.00	DELIVERED	UPI
ORDFDD1CC0671	467	3	20260929	8	Paneer Tikka	1	260.00	260.00	DELIVERED	COD
ORD14DF53ACD7	1111	6	20260926	20	Cheese Burger	4	150.00	600.00	DELIVERED	CARD
ORD203988B3AF	850	3	20260726	14	Garlic Naan	3	60.00	180.00	PLACED	COD
ORD98D68FBE2B	532	17	20260920	21	Chicken Biryani	4	280.00	1120.00	DELIVERED	UPI
ORDE13F0A7FB3	409	19	20260928	20	Idli Sambar	3	80.00	240.00	DELIVERED	COD
ORD5F9FC1C51F	122	9	20261006	14	Tandoori Chicken	3	340.00	1020.00	DELIVERED	CARD
ORDC9A5695A67	181	2	20260902	19	Miso Soup	2	150.00	300.00	DELIVERED	UPI
ORD982F84CC06	89	19	20260719	20	Masala Dosa	2	110.00	220.00	DELIVERED	UPI
ORDEC011B5D7B	346	17	20260828	13	Veg Biryani	4	220.00	880.00	DELIVERED	COD
ORDC363BA9101	811	9	20260804	21	Tandoori Chicken	4	340.00	1360.00	DELIVERED	UPI
ORDD0F5700B9D	360	6	20260821	14	Cheese Burger	3	150.00	450.00	DELIVERED	COD
ORD20AD293574	102	3	20260913	13	Dal Makhani	4	220.00	880.00	DELIVERED	COD
ORDCF29E33AEC	134	6	20261005	21	Chicken Wrap	4	140.00	560.00	DELIVERED	COD
ORDE04F2D4F26	966	4	20260805	13	Garlic Bread	4	120.00	480.00	CANCELLED	UPI
ORDF4EA106D7B	346	19	20260919	13	Filter Coffee	4	40.00	160.00	DELIVERED	UPI
ORDB884A3A6DE	1125	6	20261003	20	French Fries	3	90.00	270.00	DELIVERED	UPI
ORD68878296FC	28	17	20260919	17	Veg Biryani	1	220.00	220.00	DELIVERED	CARD
ORD1F335C443C	3	2	20261013	20	Ramen Bowl	2	380.00	760.00	DELIVERED	CARD
ORDE5EBE21567	264	2	20261005	20	Ramen Bowl	4	380.00	1520.00	DELIVERED	COD
ORD5A8D235264	112	17	20260726	8	Veg Biryani	1	220.00	220.00	DELIVERED	CARD
\.


--
-- Data for Name: rejected_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.rejected_orders (id, order_id, payload, reason, rejected_at) FROM stdin;
1	ORD1001	{"status": "DELIVERED", "cuisine": "Indian", "order_id": "ORD1001", "quantity": 2, "item_name": "Paneer Biryani", "order_time": "2026-10-10T18:30:00", "unit_price": 250.0, "customer_id": "CUST101", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "REST201", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	duplicate order_id	2026-10-10 15:27:04.784615
2	ORD1001	{"status": "DELIVERED", "cuisine": "Indian", "order_id": "ORD1001", "quantity": 2, "item_name": "Paneer Biryani", "order_time": "2026-10-10T18:30:00", "unit_price": 250.0, "customer_id": "CUST101", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "REST201", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	duplicate order_id	2026-10-10 15:27:04.784615
3	ORD3EABD56B9C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD3EABD56B9C", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-07-27T21:07:00", "unit_price": -299.0, "customer_id": "C0175", "customer_city": "Mumbai", "customer_name": "Sahil Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	unit_price out of range	2026-10-10 15:27:04.784615
4	ORDC4733953DC	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDC4733953DC", "quantity": 0, "item_name": "Garlic Bread", "order_time": "2026-08-24T22:17:00", "unit_price": 120.0, "customer_id": "C0344", "customer_city": "Mumbai", "customer_name": "Kabir Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	quantity must be > 0	2026-10-10 15:27:04.784615
5	ORD5BAE31F3EB	{"status": "CANCELLED", "cuisine": "Italian", "order_id": "ORD5BAE31F3EB", "quantity": 0, "item_name": "Garlic Bread", "order_time": "2026-07-21T20:11:00", "unit_price": 120.0, "customer_id": "C0214", "customer_city": "Mumbai", "customer_name": "Pooja Joshi", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	quantity must be > 0	2026-10-10 15:27:04.784615
6	ORDC02F199A6A	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDC02F199A6A", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-07-26T08:20:00", "unit_price": 120.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Aarav Iyer", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	missing customer_id	2026-10-10 15:27:04.784615
7	ORD241B383085	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD241B383085", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-09-29T20:44:00", "unit_price": 190.0, "customer_id": "C0322", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	duplicate order_id	2026-10-10 15:27:04.784615
8	ORDA1365B3CA2	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDA1365B3CA2", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-08-05T12:58:00", "unit_price": 210.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Kabir Iyer", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	missing customer_id	2026-10-10 15:27:04.784615
9	ORD34897ABBD4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD34897ABBD4", "quantity": 0, "item_name": "Paneer Tikka", "order_time": "2026-07-19T20:41:00", "unit_price": 260.0, "customer_id": "C0129", "customer_city": "MUMBAI", "customer_name": "  riya patil ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	quantity must be > 0	2026-10-10 15:27:04.784615
10	ORD18BBA7A73E	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD18BBA7A73E", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-09-13T17:14:00", "unit_price": 140.0, "customer_id": "C0302", "customer_city": "Pune", "customer_name": "Priya Khan", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	duplicate order_id	2026-10-10 15:27:04.784615
11	ORDD2FBCEA5FD	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDD2FBCEA5FD", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-22T19:12:00", "unit_price": 180.0, "customer_id": "C0062", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	duplicate order_id	2026-10-10 15:27:04.784615
12	ORD1361034724	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1361034724", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-07-15T22:04:00", "unit_price": -210.0, "customer_id": "C0344", "customer_city": "Mumbai", "customer_name": "Kabir Patil", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	unit_price out of range	2026-10-10 15:27:04.784615
13	ORD4103BE1E52	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4103BE1E52", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-10-05T20:48:00", "unit_price": -320.0, "customer_id": "C0161", "customer_city": "Mumbai", "customer_name": "Rohan Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	unit_price out of range	2026-10-10 15:27:04.784615
14	ORD16ACC826A0	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD16ACC826A0", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-09-19T09:19:00", "unit_price": 190.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Riya Desai", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	missing customer_id	2026-10-10 15:27:04.784615
15	ORDBA3D0066EC	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDBA3D0066EC", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-10-05T22:13:00", "unit_price": 299.0, "customer_id": "C0067", "customer_city": "Mumbai", "customer_name": "Aarav Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	duplicate order_id	2026-10-10 15:27:04.784615
16	ORDA0AB8C8D07	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA0AB8C8D07", "quantity": 4, "item_name": "Idli Sambar", "order_time": "2026-08-20T09:50:00", "unit_price": 80.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Vikram Patil", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	missing customer_id	2026-10-10 15:27:04.784615
17	ORD553BD4E999	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD553BD4E999", "quantity": 3, "item_name": "Raita", "order_time": "2026-07-24T08:24:00", "unit_price": 40.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Arjun Patil", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	missing customer_id	2026-10-10 15:27:04.784615
18	ORD2839214D6C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD2839214D6C", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-08-20T13:09:00", "unit_price": 190.0, "customer_id": "C0276", "customer_city": "Mumbai", "customer_name": "Arjun Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	duplicate order_id	2026-10-10 15:27:04.784615
19	ORDD4A0BF0D04	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDD4A0BF0D04", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-07-26T13:49:00", "unit_price": -80.0, "customer_id": "C0057", "customer_city": "Pune", "customer_name": "Rohan Joshi", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	unit_price out of range	2026-10-10 15:27:04.784615
20	ORDE6B14A6F5F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE6B14A6F5F", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-01T21:12:00", "unit_price": 150.0, "customer_id": "C0378", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	duplicate order_id	2026-10-10 15:27:04.784615
21	ORD634C47C015	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD634C47C015", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-07-31T20:04:00", "unit_price": 150.0, "customer_id": null, "customer_city": "THANE", "customer_name": "  rohan sharma ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	missing customer_id	2026-10-10 15:27:04.784615
22	ORD59A189084D	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD59A189084D", "quantity": 0, "item_name": "Veg Biryani", "order_time": "2026-08-03T14:09:00", "unit_price": 220.0, "customer_id": "C0189", "customer_city": "PUNE", "customer_name": "  aarav patil ", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	quantity must be > 0	2026-10-10 15:27:04.784615
23	ORD1855B7B2E2	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1855B7B2E2", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-08-28T19:11:00", "unit_price": 180.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	missing customer_id	2026-10-10 15:27:04.784615
24	ORD117A49CEFB	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD117A49CEFB", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-14T16:01:00", "unit_price": 55.0, "customer_id": "C0347", "customer_city": "Thane", "customer_name": "Sahil Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	duplicate order_id	2026-10-10 15:27:04.784615
25	ORDD5B5DCEACC	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDD5B5DCEACC", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-09-21T17:51:00", "unit_price": 140.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Anjali Kulkarni", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	missing customer_id	2026-10-10 15:27:04.784615
26	ORD0B64478E91	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD0B64478E91", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-07-13T13:49:00", "unit_price": 110.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Rohan Desai", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	missing customer_id	2026-10-10 15:27:04.784615
27	ORDD9002408A0	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORDD9002408A0", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-31T17:40:00", "unit_price": -150.0, "customer_id": "C0277", "customer_city": "Thane", "customer_name": "Anjali Sharma", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	unit_price out of range	2026-10-10 15:27:04.784615
28	ORD7D58E7C4C9	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD7D58E7C4C9", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-08-25T19:33:00", "unit_price": -110.0, "customer_id": "C0234", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	unit_price out of range	2026-10-10 15:27:04.784615
29	ORDCAF5DB2AE0	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDCAF5DB2AE0", "quantity": 0, "item_name": "Garlic Bread", "order_time": "2026-08-08T22:50:00", "unit_price": 120.0, "customer_id": "C0268", "customer_city": "Mumbai", "customer_name": "Arjun Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	quantity must be > 0	2026-10-10 15:27:04.784615
30	ORD5AA65BF58D	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5AA65BF58D", "quantity": 0, "item_name": "Chicken Wrap", "order_time": "2026-07-19T20:24:00", "unit_price": 140.0, "customer_id": "C0120", "customer_city": "Pune", "customer_name": "Vikram Singh", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	quantity must be > 0	2026-10-10 15:27:04.784615
31	ORDBA2BB94712	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDBA2BB94712", "quantity": 0, "item_name": "Paneer Tikka", "order_time": "2026-07-21T22:26:00", "unit_price": 260.0, "customer_id": "C0106", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	quantity must be > 0	2026-10-10 15:27:04.784615
32	ORD892F9180F9	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD892F9180F9", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-10-09T21:30:00", "unit_price": 40.0, "customer_id": "C0134", "customer_city": "Pune", "customer_name": "Aarav Patil", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	duplicate order_id	2026-10-10 15:27:04.784615
33	ORD5EFB4F65FD	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5EFB4F65FD", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-07-29T14:47:00", "unit_price": 150.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Pooja Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	missing customer_id	2026-10-10 15:27:04.784615
34	ORD91A1EB126C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD91A1EB126C", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-08-30T16:47:00", "unit_price": 55.0, "customer_id": null, "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	missing customer_id	2026-10-10 15:27:04.784615
35	ORD3BD38034C4	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD3BD38034C4", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-08-15T21:40:00", "unit_price": -120.0, "customer_id": "C0354", "customer_city": "Mumbai", "customer_name": "Arjun Sharma", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	unit_price out of range	2026-10-10 15:27:04.784615
36	ORDD2FBCEA5FD	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDD2FBCEA5FD", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-22T19:12:00", "unit_price": 180.0, "customer_id": "C0062", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	duplicate order_id	2026-10-10 15:27:04.784615
37	ORDA13A496B3B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA13A496B3B", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-08-11T17:23:00", "unit_price": 150.0, "customer_id": "C0124", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	duplicate order_id	2026-10-10 15:27:04.784615
38	ORDE6B14A6F5F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE6B14A6F5F", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-01T21:12:00", "unit_price": 150.0, "customer_id": "C0378", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	duplicate order_id	2026-10-10 15:27:04.784615
39	ORDFB58B99186	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDFB58B99186", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-08-30T20:24:00", "unit_price": 120.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Rohan Mehta", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	missing customer_id	2026-10-10 15:27:04.784615
40	ORD9CA83824E0	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD9CA83824E0", "quantity": 0, "item_name": "Masala Dosa", "order_time": "2026-09-10T19:24:00", "unit_price": 110.0, "customer_id": "C0215", "customer_city": "Pune", "customer_name": "Sahil Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	quantity must be > 0	2026-10-10 15:27:04.784615
41	ORD748CA8F4F0	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD748CA8F4F0", "quantity": 0, "item_name": "Filter Coffee", "order_time": "2026-08-31T22:29:00", "unit_price": 40.0, "customer_id": "C0217", "customer_city": "Pune", "customer_name": "Pooja Nair", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	quantity must be > 0	2026-10-14 12:59:50.323702
42	ORD0616204282	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD0616204282", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-08-31T20:54:00", "unit_price": -150.0, "customer_id": "C0175", "customer_city": "Pune", "customer_name": "Kabir Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	unit_price out of range	2026-10-14 12:59:50.323702
43	ORDE52A710878	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE52A710878", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-10-08T13:27:00", "unit_price": 190.0, "customer_id": "C0353", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	duplicate order_id	2026-10-14 12:59:50.323702
44	ORD8796FF375C	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD8796FF375C", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-24T17:25:00", "unit_price": 150.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	missing customer_id	2026-10-14 12:59:50.323702
45	ORD46A94248C1	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD46A94248C1", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-15T22:29:00", "unit_price": -280.0, "customer_id": "C0274", "customer_city": "Mumbai", "customer_name": "Aarav Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	unit_price out of range	2026-10-14 12:59:50.323702
46	ORD5420C3416D	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD5420C3416D", "quantity": 0, "item_name": "Manchurian", "order_time": "2026-09-07T22:07:00", "unit_price": 210.0, "customer_id": "C0224", "customer_city": "Mumbai", "customer_name": "Neha Joshi", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	quantity must be > 0	2026-10-14 12:59:50.323702
47	ORDD10B600B3B	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORDD10B600B3B", "quantity": 0, "item_name": "Masala Dosa", "order_time": "2026-07-20T12:14:00", "unit_price": 110.0, "customer_id": "C0002", "customer_city": "Pune", "customer_name": "Rohan Singh", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	quantity must be > 0	2026-10-14 12:59:50.323702
48	ORD5AE5953511	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD5AE5953511", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-08T22:26:00", "unit_price": 280.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Riya Singh", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	missing customer_id	2026-10-14 12:59:50.323702
49	ORDBD3C7CFE01	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDBD3C7CFE01", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-07-26T17:41:00", "unit_price": 210.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Priya Iyer", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	missing customer_id	2026-10-14 12:59:50.323702
50	ORD1CE7FD768B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD1CE7FD768B", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-09-21T13:44:00", "unit_price": 260.0, "customer_id": "C0065", "customer_city": "Mumbai", "customer_name": "Vikram Joshi", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	duplicate order_id	2026-10-14 12:59:50.323702
51	ORD064C4A583B	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD064C4A583B", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-09-05T21:13:00", "unit_price": -210.0, "customer_id": "C0204", "customer_city": "Mumbai", "customer_name": "Arjun Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	unit_price out of range	2026-10-14 12:59:50.323702
52	ORD5DEB07C359	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5DEB07C359", "quantity": 0, "item_name": "Butter Chicken", "order_time": "2026-08-26T21:59:00", "unit_price": 320.0, "customer_id": "C0350", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	quantity must be > 0	2026-10-14 12:59:50.323702
53	ORD27CE4682E0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD27CE4682E0", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-07-30T13:21:00", "unit_price": 340.0, "customer_id": "C0348", "customer_city": "Thane", "customer_name": "Rohan Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	duplicate order_id	2026-10-14 12:59:50.323702
54	ORDF095100E56	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF095100E56", "quantity": 0, "item_name": "Paneer Butter Masala", "order_time": "2026-10-01T17:54:00", "unit_price": 250.0, "customer_id": "C0380", "customer_city": "Thane", "customer_name": "Pooja Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	quantity must be > 0	2026-10-14 12:59:50.323702
55	ORD0B8A2899E8	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD0B8A2899E8", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-29T20:15:00", "unit_price": 220.0, "customer_id": "C0140", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	duplicate order_id	2026-10-14 12:59:50.323702
56	ORDC41F2572D8	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC41F2572D8", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-09-24T20:25:00", "unit_price": 250.0, "customer_id": null, "customer_city": "Thane", "customer_name": "Neha Patil", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	missing customer_id	2026-10-14 12:59:50.323702
57	ORD62465643AA	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD62465643AA", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-07-20T22:14:00", "unit_price": -350.0, "customer_id": "C0324", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	unit_price out of range	2026-10-14 12:59:50.323702
58	ORDC8CEF29301	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDC8CEF29301", "quantity": 0, "item_name": "Masala Dosa", "order_time": "2026-07-30T13:32:00", "unit_price": 110.0, "customer_id": "C0375", "customer_city": "Pune", "customer_name": "Arjun Nair", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	quantity must be > 0	2026-10-14 12:59:50.323702
59	ORD544AB37209	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD544AB37209", "quantity": 0, "item_name": "Veg Biryani", "order_time": "2026-08-18T08:24:00", "unit_price": 220.0, "customer_id": "C0368", "customer_city": "Pune", "customer_name": "Vikram Nair", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	quantity must be > 0	2026-10-14 12:59:50.323702
60	ORD71D5C99AD5	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD71D5C99AD5", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-09-10T14:19:00", "unit_price": 80.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Arjun Mehta", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	missing customer_id	2026-10-14 12:59:50.323702
61	ORDC265BA3C3B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC265BA3C3B", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-08-19T12:04:00", "unit_price": -60.0, "customer_id": "C0272", "customer_city": "Mumbai", "customer_name": "Sneha Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	unit_price out of range	2026-10-14 12:59:50.323702
62	ORDE240EB37DE	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE240EB37DE", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-08T13:32:00", "unit_price": -150.0, "customer_id": "C0317", "customer_city": "Pune", "customer_name": "Sahil Desai", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	unit_price out of range	2026-10-14 12:59:50.323702
63	ORDE294E2F958	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE294E2F958", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-11T08:58:00", "unit_price": 380.0, "customer_id": "C0212", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	duplicate order_id	2026-10-14 12:59:50.323702
64	ORDA257D52115	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA257D52115", "quantity": 0, "item_name": "Idli Sambar", "order_time": "2026-09-22T09:44:00", "unit_price": 80.0, "customer_id": "C0200", "customer_city": "Pune", "customer_name": "Riya Iyer", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	quantity must be > 0	2026-10-14 12:59:50.323702
65	ORDFF18756410	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDFF18756410", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-01T21:26:00", "unit_price": 280.0, "customer_id": "C0026", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	duplicate order_id	2026-10-14 12:59:50.323702
66	ORD0B78DD260C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD0B78DD260C", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-28T17:30:00", "unit_price": -350.0, "customer_id": "C0081", "customer_city": "Thane", "customer_name": "Neha Mehta", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	unit_price out of range	2026-10-14 12:59:50.323702
67	ORDC638620998	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC638620998", "quantity": 2, "item_name": "French Fries", "order_time": "2026-08-18T20:25:00", "unit_price": 90.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	missing customer_id	2026-10-14 12:59:50.323702
68	ORD73BF55CE5C	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD73BF55CE5C", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-07-22T22:54:00", "unit_price": 150.0, "customer_id": "C0328", "customer_city": "Pune", "customer_name": "Vikram Joshi", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	duplicate order_id	2026-10-14 12:59:50.323702
69	ORD1CCEDC6900	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORD1CCEDC6900", "quantity": 1, "item_name": "Masala Dosa", "order_time": "2026-09-30T20:09:00", "unit_price": -110.0, "customer_id": "C0191", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	unit_price out of range	2026-10-14 12:59:50.323702
70	ORDC3E651DF57	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC3E651DF57", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-07-24T09:52:00", "unit_price": 140.0, "customer_id": "C0144", "customer_city": "Pune", "customer_name": "Neha Sharma", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	duplicate order_id	2026-10-14 12:59:50.323702
71	ORDF5CC897A78	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF5CC897A78", "quantity": 0, "item_name": "Paneer Butter Masala", "order_time": "2026-08-24T16:52:00", "unit_price": 250.0, "customer_id": "C0007", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	quantity must be > 0	2026-10-14 12:59:50.323702
72	ORD79BA4AB342	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD79BA4AB342", "quantity": 0, "item_name": "Veg Sushi Roll", "order_time": "2026-08-20T20:13:00", "unit_price": 350.0, "customer_id": "C0377", "customer_city": "Thane", "customer_name": "Aarav Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	quantity must be > 0	2026-10-14 12:59:50.323702
73	ORDC5C7F04D59	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC5C7F04D59", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-09-22T16:52:00", "unit_price": -220.0, "customer_id": "C0162", "customer_city": "Mumbai", "customer_name": "Vikram Sharma", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	unit_price out of range	2026-10-14 12:59:50.323702
74	ORDCE4FC087BC	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDCE4FC087BC", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-29T14:18:00", "unit_price": 220.0, "customer_id": "C0300", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	duplicate order_id	2026-10-14 12:59:50.323702
\.


--
-- Data for Name: stg_orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.stg_orders (id, order_id, payload, received_at, processed) FROM stdin;
1204	ORDTEST9001	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDTEST9001", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-10-14T18:30:00", "unit_price": 250.0, "customer_id": "CUST9001", "customer_city": "Mumbai", "customer_name": "Test Customer", "restaurant_id": "REST001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 13:02:48.591081	f
604	ORD6142918805	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6142918805", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-08-04T21:12:00", "unit_price": 55.0, "customer_id": "C0044", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.335613	t
605	ORD6F7793E17D	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD6F7793E17D", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-01T17:51:00", "unit_price": 350.0, "customer_id": "C0354", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.340519	t
606	ORD18D3806DC7	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD18D3806DC7", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-09-15T14:08:00", "unit_price": 320.0, "customer_id": "C0339", "customer_city": "Mumbai", "customer_name": "Anjali Nair", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.341643	t
1	ORD1001	{"status": "DELIVERED", "cuisine": "Indian", "order_id": "ORD1001", "quantity": 2, "item_name": "Paneer Biryani", "order_time": "2026-10-10T18:30:00", "unit_price": 250.0, "customer_id": "CUST101", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "REST201", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:25:29.752212	t
2	ORD1001	{"status": "DELIVERED", "cuisine": "Indian", "order_id": "ORD1001", "quantity": 2, "item_name": "Paneer Biryani", "order_time": "2026-10-10T18:30:00", "unit_price": 250.0, "customer_id": "CUST101", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "REST201", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:25:29.754816	t
3	ORD1001	{"status": "DELIVERED", "cuisine": "Indian", "order_id": "ORD1001", "quantity": 2, "item_name": "Paneer Biryani", "order_time": "2026-10-10T18:30:00", "unit_price": 250.0, "customer_id": "CUST101", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "REST201", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:25:29.755854	t
4	ORD628949BB6C	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORD628949BB6C", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-07-30T13:09:00", "unit_price": 380.0, "customer_id": "C0293", "customer_city": "Thane", "customer_name": "Vikram Sharma", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.265396	t
5	ORD3E385A31DA	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3E385A31DA", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-07-24T13:37:00", "unit_price": 320.0, "customer_id": "C0187", "customer_city": "Mumbai", "customer_name": "Aarav Kulkarni", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.268914	t
6	ORD8BFF85479A	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD8BFF85479A", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-08-25T21:48:00", "unit_price": 299.0, "customer_id": "C0229", "customer_city": "Mumbai", "customer_name": "Vikram Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.270109	t
7	ORD890ED0C5F5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD890ED0C5F5", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-08-29T21:15:00", "unit_price": 320.0, "customer_id": "C0203", "customer_city": "MUMBAI", "customer_name": "  sneha patil ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.271816	t
8	ORD18BBA7A73E	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD18BBA7A73E", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-09-13T17:14:00", "unit_price": 140.0, "customer_id": "C0302", "customer_city": "Pune", "customer_name": "Priya Khan", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.273001	t
9	ORD0511B47E15	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD0511B47E15", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-09-27T13:13:00", "unit_price": 120.0, "customer_id": "C0002", "customer_city": "Mumbai", "customer_name": "Pooja Patil", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.274805	t
10	ORDF675D1E916	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDF675D1E916", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-08-22T21:50:00", "unit_price": 280.0, "customer_id": "C0175", "customer_city": "Mumbai", "customer_name": "Sahil Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.276492	t
11	ORD3EABD56B9C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD3EABD56B9C", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-07-27T21:07:00", "unit_price": -299.0, "customer_id": "C0175", "customer_city": "Mumbai", "customer_name": "Sahil Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.277919	t
12	ORD4AFFC2D989	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4AFFC2D989", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-27T20:09:00", "unit_price": 340.0, "customer_id": "C0183", "customer_city": "Thane", "customer_name": "Arjun Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.27941	t
13	ORDCAD27B6CB8	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDCAD27B6CB8", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-08-05T21:32:00", "unit_price": 190.0, "customer_id": "C0219", "customer_city": "Mumbai", "customer_name": "Pooja Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.281078	t
14	ORD7E2F63DD7D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7E2F63DD7D", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-07-24T13:06:00", "unit_price": 320.0, "customer_id": "C0128", "customer_city": "Mumbai", "customer_name": "Priya Sharma", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.282642	t
15	ORDAE98857C28	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAE98857C28", "quantity": 3, "item_name": "Butter Chicken", "order_time": "2026-09-23T21:12:00", "unit_price": 320.0, "customer_id": "C0240", "customer_city": "MUMBAI", "customer_name": "  aarav mehta ", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.284048	t
16	ORDC4733953DC	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDC4733953DC", "quantity": 0, "item_name": "Garlic Bread", "order_time": "2026-08-24T22:17:00", "unit_price": 120.0, "customer_id": "C0344", "customer_city": "Mumbai", "customer_name": "Kabir Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.285526	t
17	ORD84D4DCAC4D	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD84D4DCAC4D", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-09-23T17:04:00", "unit_price": 150.0, "customer_id": "C0391", "customer_city": "PUNE", "customer_name": "  aarav patil ", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.286931	t
18	ORD422F351342	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD422F351342", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-08-30T22:06:00", "unit_price": 180.0, "customer_id": "C0096", "customer_city": "Mumbai", "customer_name": "Neha Desai", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.288806	t
19	ORDDCE7538742	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDDCE7538742", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-09-07T16:41:00", "unit_price": 210.0, "customer_id": "C0136", "customer_city": "Mumbai", "customer_name": "Neha Joshi", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.290671	t
20	ORD75191839D7	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD75191839D7", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-26T13:28:00", "unit_price": 340.0, "customer_id": "C0167", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.292331	t
21	ORDF0D752CCF5	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDF0D752CCF5", "quantity": 2, "item_name": "Raita", "order_time": "2026-09-24T21:27:00", "unit_price": 40.0, "customer_id": "C0284", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.293828	t
22	ORD5BAE31F3EB	{"status": "CANCELLED", "cuisine": "Italian", "order_id": "ORD5BAE31F3EB", "quantity": 0, "item_name": "Garlic Bread", "order_time": "2026-07-21T20:11:00", "unit_price": 120.0, "customer_id": "C0214", "customer_city": "Mumbai", "customer_name": "Pooja Joshi", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.295396	t
23	ORDC02F199A6A	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDC02F199A6A", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-07-26T08:20:00", "unit_price": 120.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Aarav Iyer", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.297021	t
24	ORD49413A5F8E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD49413A5F8E", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-09-15T20:51:00", "unit_price": 250.0, "customer_id": "C0244", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.29847	t
25	ORD88816BD4A6	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD88816BD4A6", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-08-19T16:20:00", "unit_price": 110.0, "customer_id": "C0153", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.300428	t
26	ORD0146B8278E	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD0146B8278E", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-08-26T16:09:00", "unit_price": 120.0, "customer_id": "C0299", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.302163	t
27	ORD474BD33A10	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD474BD33A10", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-09-29T12:11:00", "unit_price": 110.0, "customer_id": "C0210", "customer_city": "Pune", "customer_name": "Sneha Nair", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.304138	t
28	ORD2DB4AF01A7	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD2DB4AF01A7", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-08-19T14:23:00", "unit_price": 299.0, "customer_id": "C0105", "customer_city": "Mumbai", "customer_name": "Neha Nair", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.305993	t
29	ORDAAFEEDABC2	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAAFEEDABC2", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-08-18T21:22:00", "unit_price": 380.0, "customer_id": "C0155", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.307607	t
30	ORDA2DEB4B5D2	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORDA2DEB4B5D2", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-09-28T20:51:00", "unit_price": 110.0, "customer_id": "C0294", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.309287	t
31	ORDEDD03CB8F9	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDEDD03CB8F9", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-08-26T19:26:00", "unit_price": 190.0, "customer_id": "C0185", "customer_city": "Mumbai", "customer_name": "Priya Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.311027	t
32	ORDFF2EA29F97	{"status": "PLACED", "cuisine": "Hyderabadi", "order_id": "ORDFF2EA29F97", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-08-19T17:20:00", "unit_price": 220.0, "customer_id": "C0393", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.312739	t
33	ORD4D9A997E65	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD4D9A997E65", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-09-06T20:46:00", "unit_price": 40.0, "customer_id": "C0140", "customer_city": "Pune", "customer_name": "Priya Sharma", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.314704	t
34	ORDEF880B684F	{"status": "PLACED", "cuisine": "Japanese", "order_id": "ORDEF880B684F", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-29T13:16:00", "unit_price": 350.0, "customer_id": "C0068", "customer_city": "THANE", "customer_name": "  aarav nair ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.316585	t
35	ORDD8F19E4294	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDD8F19E4294", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-08-04T12:41:00", "unit_price": 80.0, "customer_id": "C0360", "customer_city": "Pune", "customer_name": "Pooja Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.318366	t
36	ORDB37F3C4BDC	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDB37F3C4BDC", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-09-05T13:49:00", "unit_price": 80.0, "customer_id": "C0367", "customer_city": "Pune", "customer_name": "Neha Nair", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.319972	t
37	ORD5953D28E15	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5953D28E15", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-10-03T13:03:00", "unit_price": 340.0, "customer_id": "C0031", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.32163	t
38	ORDF252C5B271	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDF252C5B271", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-07-25T19:22:00", "unit_price": 190.0, "customer_id": "C0079", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.323274	t
39	ORD1B180251EB	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD1B180251EB", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-07-20T16:14:00", "unit_price": 150.0, "customer_id": "C0041", "customer_city": "Pune", "customer_name": "Sahil Kulkarni", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.325181	t
40	ORD36D2EFB69C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD36D2EFB69C", "quantity": 1, "item_name": "Manchurian", "order_time": "2026-07-24T12:13:00", "unit_price": 210.0, "customer_id": "C0287", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.326957	t
41	ORD922CA88B15	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD922CA88B15", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-09-07T20:32:00", "unit_price": 320.0, "customer_id": "C0354", "customer_city": "Mumbai", "customer_name": "Arjun Sharma", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.328464	t
42	ORDDE9CBDA759	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDDE9CBDA759", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-09-15T09:35:00", "unit_price": 260.0, "customer_id": "C0266", "customer_city": "Mumbai", "customer_name": "Neha Patil", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.330363	t
43	ORD393169E53A	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD393169E53A", "quantity": 4, "item_name": "French Fries", "order_time": "2026-08-01T08:07:00", "unit_price": 90.0, "customer_id": "C0160", "customer_city": "Pune", "customer_name": "Kabir Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.33209	t
44	ORD0BD81F6879	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0BD81F6879", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-07-14T19:13:00", "unit_price": 260.0, "customer_id": "C0338", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.333795	t
45	ORD241B383085	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD241B383085", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-09-29T20:44:00", "unit_price": 190.0, "customer_id": "C0322", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.335201	t
46	ORDBDD75971C5	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDBDD75971C5", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-08-07T08:02:00", "unit_price": 120.0, "customer_id": "C0185", "customer_city": "Mumbai", "customer_name": "Priya Patil", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.336782	t
47	ORDF1E3A81964	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDF1E3A81964", "quantity": 2, "item_name": "French Fries", "order_time": "2026-10-02T09:45:00", "unit_price": 90.0, "customer_id": "C0008", "customer_city": "Pune", "customer_name": "Sneha Sharma", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.339086	t
48	ORD9AF839FE8D	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD9AF839FE8D", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-08-13T13:59:00", "unit_price": 55.0, "customer_id": "C0228", "customer_city": "Thane", "customer_name": "Sneha Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.341154	t
49	ORDFDB677F9EE	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDFDB677F9EE", "quantity": 3, "item_name": "Masala Dosa", "order_time": "2026-09-14T14:47:00", "unit_price": 110.0, "customer_id": "C0057", "customer_city": "Pune", "customer_name": "Rohan Joshi", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.342931	t
50	ORD9DC5DD4361	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9DC5DD4361", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-08-01T09:00:00", "unit_price": 380.0, "customer_id": "C0204", "customer_city": "Thane", "customer_name": "Anjali Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.344987	t
51	ORD1DF83FC535	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD1DF83FC535", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-10-08T08:51:00", "unit_price": 380.0, "customer_id": "C0145", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.346853	t
52	ORDBA3D0066EC	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDBA3D0066EC", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-10-05T22:13:00", "unit_price": 299.0, "customer_id": "C0067", "customer_city": "Mumbai", "customer_name": "Aarav Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.348468	t
53	ORD058106691B	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD058106691B", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-10-07T16:04:00", "unit_price": 210.0, "customer_id": "C0371", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.350424	t
54	ORD42E3C80F06	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD42E3C80F06", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-07-23T13:03:00", "unit_price": 180.0, "customer_id": "C0288", "customer_city": "Mumbai", "customer_name": "Kabir Iyer", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.351947	t
55	ORD26EC95F59D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD26EC95F59D", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-08-27T12:37:00", "unit_price": 60.0, "customer_id": "C0258", "customer_city": "MUMBAI", "customer_name": "  neha desai ", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.354224	t
56	ORD241B383085	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD241B383085", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-09-29T20:44:00", "unit_price": 190.0, "customer_id": "C0322", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.3562	t
57	ORD4AB02ACF88	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4AB02ACF88", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-03T13:57:00", "unit_price": 55.0, "customer_id": "C0032", "customer_city": "THANE", "customer_name": "  vikram joshi ", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.358122	t
58	ORD3EABD56B9C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD3EABD56B9C", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-07-27T21:07:00", "unit_price": 299.0, "customer_id": "C0175", "customer_city": "Mumbai", "customer_name": "Sahil Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.359767	t
59	ORD643269EAD3	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD643269EAD3", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-08-18T21:58:00", "unit_price": 60.0, "customer_id": "C0226", "customer_city": "Mumbai", "customer_name": "Sahil Iyer", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.361362	t
60	ORDE6B14A6F5F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE6B14A6F5F", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-01T21:12:00", "unit_price": 150.0, "customer_id": "C0378", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.36313	t
61	ORD2FFC24961E	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD2FFC24961E", "quantity": 4, "item_name": "Raita", "order_time": "2026-09-22T09:46:00", "unit_price": 40.0, "customer_id": "C0348", "customer_city": "Pune", "customer_name": "Anjali Joshi", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.364971	t
62	ORDDC70788C73	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDDC70788C73", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-07-25T13:02:00", "unit_price": 40.0, "customer_id": "C0208", "customer_city": "Pune", "customer_name": "Sahil Desai", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.366744	t
63	ORD19D11CF0DE	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORD19D11CF0DE", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-10-01T09:08:00", "unit_price": 180.0, "customer_id": "C0265", "customer_city": "Mumbai", "customer_name": "Riya Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.368259	t
64	ORDCB81CB9933	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORDCB81CB9933", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-08-28T12:34:00", "unit_price": 260.0, "customer_id": "C0267", "customer_city": "Mumbai", "customer_name": "Riya Nair", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.370579	t
65	ORD8F2B20F0BE	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD8F2B20F0BE", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-26T20:38:00", "unit_price": 150.0, "customer_id": "C0145", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.372527	t
66	ORD3F80A58837	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3F80A58837", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-07-31T21:01:00", "unit_price": 350.0, "customer_id": "C0384", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.374926	t
67	ORD402577B739	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD402577B739", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-09-18T20:41:00", "unit_price": 280.0, "customer_id": "C0253", "customer_city": "Pune", "customer_name": "Neha Nair", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.376739	t
68	ORDE6A6D92F63	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE6A6D92F63", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-08-26T21:10:00", "unit_price": 299.0, "customer_id": "C0258", "customer_city": "Mumbai", "customer_name": "Neha Desai", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.378299	t
69	ORD7E7B52B8BA	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD7E7B52B8BA", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-10T13:52:00", "unit_price": 280.0, "customer_id": "C0235", "customer_city": "Mumbai", "customer_name": "Anjali Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.379669	t
70	ORD9EA78815E3	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD9EA78815E3", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-09-26T19:21:00", "unit_price": 120.0, "customer_id": "C0198", "customer_city": "Mumbai", "customer_name": "Pooja Patil", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.381872	t
71	ORD4E1227217B	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORD4E1227217B", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-07-22T16:44:00", "unit_price": 340.0, "customer_id": "C0230", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.383523	t
72	ORDA1365B3CA2	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDA1365B3CA2", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-08-05T12:58:00", "unit_price": 210.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Kabir Iyer", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.384907	t
73	ORD3E2D22883A	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD3E2D22883A", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-09-09T12:48:00", "unit_price": 40.0, "customer_id": "C0186", "customer_city": "Pune", "customer_name": "Neha Singh", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.38699	t
74	ORDD2FBCEA5FD	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDD2FBCEA5FD", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-22T19:12:00", "unit_price": 180.0, "customer_id": "C0062", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.389193	t
75	ORD34897ABBD4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD34897ABBD4", "quantity": 0, "item_name": "Paneer Tikka", "order_time": "2026-07-19T20:41:00", "unit_price": 260.0, "customer_id": "C0129", "customer_city": "MUMBAI", "customer_name": "  riya patil ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.390806	t
76	ORDA18A0C36AD	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORDA18A0C36AD", "quantity": 3, "item_name": "Raita", "order_time": "2026-08-26T19:45:00", "unit_price": 40.0, "customer_id": "C0220", "customer_city": "Pune", "customer_name": "Neha Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.392443	t
77	ORD9CC36838FB	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9CC36838FB", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-08-06T17:40:00", "unit_price": 350.0, "customer_id": "C0244", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.394276	t
78	ORD246E2CF9E5	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD246E2CF9E5", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-07-26T17:27:00", "unit_price": 210.0, "customer_id": "C0170", "customer_city": "Mumbai", "customer_name": "Kabir Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.395958	t
79	ORDF737CF2BC5	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDF737CF2BC5", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-08-09T13:46:00", "unit_price": 40.0, "customer_id": "C0120", "customer_city": "Pune", "customer_name": "Vikram Singh", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.397611	t
80	ORDA791065C18	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA791065C18", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-09-30T20:58:00", "unit_price": 350.0, "customer_id": "C0218", "customer_city": "Thane", "customer_name": "Aarav Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.399094	t
81	ORD60738FE4ED	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD60738FE4ED", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-10-05T21:43:00", "unit_price": 299.0, "customer_id": "C0188", "customer_city": "Mumbai", "customer_name": "Priya Joshi", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.401378	t
82	ORDCD31DE5438	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDCD31DE5438", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-08-22T12:12:00", "unit_price": 80.0, "customer_id": "C0008", "customer_city": "Pune", "customer_name": "Sneha Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.403355	t
83	ORD2839214D6C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD2839214D6C", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-08-20T13:09:00", "unit_price": 190.0, "customer_id": "C0276", "customer_city": "Mumbai", "customer_name": "Arjun Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.406456	t
84	ORD0E396D20E2	{"status": "PLACED", "cuisine": "Japanese", "order_id": "ORD0E396D20E2", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-08-17T09:05:00", "unit_price": 350.0, "customer_id": "C0202", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.407906	t
85	ORDB33D0D8596	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB33D0D8596", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-07-26T16:39:00", "unit_price": 180.0, "customer_id": "C0245", "customer_city": "MUMBAI", "customer_name": "  vikram desai ", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.409502	t
86	ORD803CC43C87	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD803CC43C87", "quantity": 3, "item_name": "Butter Chicken", "order_time": "2026-09-29T16:01:00", "unit_price": 320.0, "customer_id": "C0144", "customer_city": "Mumbai", "customer_name": "Aarav Iyer", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.411089	t
87	ORD4C75998ABE	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD4C75998ABE", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-09-06T20:34:00", "unit_price": 190.0, "customer_id": "C0187", "customer_city": "Mumbai", "customer_name": "Aarav Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.412818	t
88	ORDCD1263BED6	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDCD1263BED6", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-10-06T22:39:00", "unit_price": 250.0, "customer_id": "C0099", "customer_city": "Thane", "customer_name": "Aarav Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.414418	t
89	ORD549EFDB258	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD549EFDB258", "quantity": 1, "item_name": "Raita", "order_time": "2026-08-17T09:51:00", "unit_price": 40.0, "customer_id": "C0007", "customer_city": "Pune", "customer_name": "Sneha Kulkarni", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.416219	t
90	ORDE10B2F5BA4	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE10B2F5BA4", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-08-03T20:06:00", "unit_price": 190.0, "customer_id": "C0267", "customer_city": "Mumbai", "customer_name": "Riya Nair", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.417723	t
91	ORD18BBA7A73E	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD18BBA7A73E", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-09-13T17:14:00", "unit_price": 140.0, "customer_id": "C0302", "customer_city": "Pune", "customer_name": "Priya Khan", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.419453	t
92	ORD3E700C079A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3E700C079A", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-08-20T19:42:00", "unit_price": 340.0, "customer_id": "C0334", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.421201	t
93	ORD5361B96C16	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD5361B96C16", "quantity": 1, "item_name": "Raita", "order_time": "2026-09-18T20:18:00", "unit_price": 40.0, "customer_id": "C0294", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.422684	t
94	ORD047F76BE52	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD047F76BE52", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-08-19T17:49:00", "unit_price": 60.0, "customer_id": "C0185", "customer_city": "Mumbai", "customer_name": "Priya Patil", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.424347	t
95	ORD0C7F2E7B52	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0C7F2E7B52", "quantity": 2, "item_name": "Garlic Naan", "order_time": "2026-09-14T13:02:00", "unit_price": 60.0, "customer_id": "C0292", "customer_city": "Mumbai", "customer_name": "Riya Nair", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.425808	t
96	ORDCC909D938E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDCC909D938E", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-10-03T17:17:00", "unit_price": 350.0, "customer_id": "C0384", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.427454	t
97	ORDBFFA1B30D5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDBFFA1B30D5", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-07-29T21:47:00", "unit_price": 220.0, "customer_id": "C0258", "customer_city": "MUMBAI", "customer_name": "  neha desai ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.42882	t
98	ORDCF6A4BBA59	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDCF6A4BBA59", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-09-15T13:54:00", "unit_price": 380.0, "customer_id": "C0141", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.430411	t
99	ORD2D158D0897	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2D158D0897", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-07-14T13:23:00", "unit_price": 350.0, "customer_id": "C0376", "customer_city": "Thane", "customer_name": "Sneha Desai", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.431829	t
100	ORD11CD2B3D63	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD11CD2B3D63", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-08-23T13:33:00", "unit_price": 320.0, "customer_id": "C0213", "customer_city": "MUMBAI", "customer_name": "  aarav iyer ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.433389	t
101	ORD322E2D81E4	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD322E2D81E4", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-08-28T21:55:00", "unit_price": 80.0, "customer_id": "C0220", "customer_city": "Pune", "customer_name": "Neha Singh", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.435223	t
102	ORD4C32D97772	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD4C32D97772", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-09-14T12:43:00", "unit_price": 190.0, "customer_id": "C0380", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.436818	t
103	ORD8D01102625	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD8D01102625", "quantity": 4, "item_name": "Idli Sambar", "order_time": "2026-10-07T20:46:00", "unit_price": 80.0, "customer_id": "C0066", "customer_city": "Pune", "customer_name": "Vikram Kulkarni", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.438314	t
104	ORDC98FF7F2F5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC98FF7F2F5", "quantity": 1, "item_name": "Paneer Tikka", "order_time": "2026-09-26T08:30:00", "unit_price": 260.0, "customer_id": "C0187", "customer_city": "Mumbai", "customer_name": "Aarav Kulkarni", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.439972	t
105	ORD3C9C14DA70	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3C9C14DA70", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-10-05T12:42:00", "unit_price": 220.0, "customer_id": "C0055", "customer_city": "Mumbai", "customer_name": "Vikram Mehta", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.441597	t
106	ORD516CD09F9E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD516CD09F9E", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-09-27T13:21:00", "unit_price": 350.0, "customer_id": "C0032", "customer_city": "Thane", "customer_name": "Vikram Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.443333	t
107	ORD6CB27DB895	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD6CB27DB895", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-08-18T20:28:00", "unit_price": 110.0, "customer_id": "C0127", "customer_city": "Pune", "customer_name": "Riya Desai", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.444616	t
108	ORDC1AFF7C8B9	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDC1AFF7C8B9", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-02T17:38:00", "unit_price": 380.0, "customer_id": "C0049", "customer_city": "Thane", "customer_name": "Pooja Patil", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.445868	t
109	ORDCBF187EB2D	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDCBF187EB2D", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-08-08T13:09:00", "unit_price": 140.0, "customer_id": "C0030", "customer_city": "Pune", "customer_name": "Riya Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.447306	t
110	ORDD52946728F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDD52946728F", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-29T20:01:00", "unit_price": 150.0, "customer_id": "C0342", "customer_city": "THANE", "customer_name": "  sneha iyer ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.449359	t
111	ORDEA0800B0A0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEA0800B0A0", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-07-28T13:18:00", "unit_price": 250.0, "customer_id": "C0090", "customer_city": "Thane", "customer_name": "Arjun Nair", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.450709	t
112	ORDAD17206EA9	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAD17206EA9", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-10-03T21:47:00", "unit_price": 250.0, "customer_id": "C0329", "customer_city": "Thane", "customer_name": "Neha Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.452187	t
113	ORD3C60D091DA	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD3C60D091DA", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-07-13T08:25:00", "unit_price": 110.0, "customer_id": "C0026", "customer_city": "Pune", "customer_name": "Kabir Khan", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.454075	t
114	ORDB594096243	{"status": "PLACED", "cuisine": "Japanese", "order_id": "ORDB594096243", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-09-16T08:23:00", "unit_price": 350.0, "customer_id": "C0061", "customer_city": "Thane", "customer_name": "Anjali Iyer", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.456354	t
115	ORDD2FBCEA5FD	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDD2FBCEA5FD", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-22T19:12:00", "unit_price": 180.0, "customer_id": "C0062", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.458179	t
116	ORD3114DBF769	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD3114DBF769", "quantity": 2, "item_name": "French Fries", "order_time": "2026-09-23T08:03:00", "unit_price": 90.0, "customer_id": "C0220", "customer_city": "Pune", "customer_name": "Neha Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.460059	t
117	ORDFC8DCCC968	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDFC8DCCC968", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-09-19T20:45:00", "unit_price": 55.0, "customer_id": "C0068", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.462045	t
118	ORD62B93883BC	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD62B93883BC", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-10T19:07:00", "unit_price": 180.0, "customer_id": "C0025", "customer_city": "Mumbai", "customer_name": "Aarav Nair", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.463999	t
119	ORD5D18798612	{"status": "PLACED", "cuisine": "Chinese", "order_id": "ORD5D18798612", "quantity": 1, "item_name": "Manchurian", "order_time": "2026-08-25T21:22:00", "unit_price": 210.0, "customer_id": "C0275", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.466054	t
120	ORDCDD43E70D1	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDCDD43E70D1", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-08-25T22:29:00", "unit_price": 180.0, "customer_id": "C0029", "customer_city": "Mumbai", "customer_name": "Sahil Desai", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.468188	t
121	ORDAC7EE254D3	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDAC7EE254D3", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-08-26T12:30:00", "unit_price": 40.0, "customer_id": "C0149", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.470145	t
122	ORD64BC71C963	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD64BC71C963", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-09-11T17:06:00", "unit_price": 40.0, "customer_id": "C0259", "customer_city": "Pune", "customer_name": "Riya Joshi", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.472122	t
123	ORDE68593BADB	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE68593BADB", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-26T22:23:00", "unit_price": 55.0, "customer_id": "C0060", "customer_city": "Thane", "customer_name": "Arjun Sharma", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.474049	t
124	ORD6345A88B42	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6345A88B42", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-10-03T21:25:00", "unit_price": 220.0, "customer_id": "C0276", "customer_city": "Mumbai", "customer_name": "Arjun Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.475855	t
125	ORD8E0AE99591	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8E0AE99591", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-10-06T13:53:00", "unit_price": 260.0, "customer_id": "C0332", "customer_city": "Mumbai", "customer_name": "Rohan Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.477557	t
126	ORD0C1C8263D7	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0C1C8263D7", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-24T19:25:00", "unit_price": 250.0, "customer_id": "C0141", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.479225	t
127	ORD9E7388C4AF	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9E7388C4AF", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-24T16:02:00", "unit_price": 380.0, "customer_id": "C0086", "customer_city": "Thane", "customer_name": "Sahil Mehta", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.48098	t
128	ORDEC0C3AF880	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDEC0C3AF880", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-07-17T13:58:00", "unit_price": 210.0, "customer_id": "C0280", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.482512	t
129	ORDE8963745DA	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE8963745DA", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-09-27T19:34:00", "unit_price": 140.0, "customer_id": "C0222", "customer_city": "Pune", "customer_name": "Vikram Desai", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.484226	t
130	ORD658CAB7A30	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD658CAB7A30", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-07-27T22:51:00", "unit_price": 250.0, "customer_id": "C0107", "customer_city": "Thane", "customer_name": "Aarav Sharma", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.486245	t
131	ORDA117074C7B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA117074C7B", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-24T16:27:00", "unit_price": 350.0, "customer_id": "C0347", "customer_city": "Thane", "customer_name": "Sahil Sharma", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.488171	t
132	ORD5CA2252421	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD5CA2252421", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-08T21:33:00", "unit_price": 150.0, "customer_id": "C0274", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.48983	t
133	ORD889CF33344	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD889CF33344", "quantity": 3, "item_name": "Raita", "order_time": "2026-07-19T22:15:00", "unit_price": 40.0, "customer_id": "C0154", "customer_city": "Pune", "customer_name": "Riya Khan", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.491782	t
134	ORD7564D5F250	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD7564D5F250", "quantity": 3, "item_name": "French Fries", "order_time": "2026-10-07T13:06:00", "unit_price": 90.0, "customer_id": "C0153", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.493356	t
135	ORDC09E5F36E2	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORDC09E5F36E2", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-08-03T20:20:00", "unit_price": 80.0, "customer_id": "C0270", "customer_city": "Pune", "customer_name": "Arjun Singh", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.494936	t
136	ORD69322BDFEB	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD69322BDFEB", "quantity": 4, "item_name": "Idli Sambar", "order_time": "2026-08-14T09:20:00", "unit_price": 80.0, "customer_id": "C0302", "customer_city": "Pune", "customer_name": "Priya Khan", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.496365	t
137	ORD1361034724	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1361034724", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-07-15T22:04:00", "unit_price": -210.0, "customer_id": "C0344", "customer_city": "Mumbai", "customer_name": "Kabir Patil", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.498085	t
138	ORDF0250DD658	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDF0250DD658", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-08-04T20:42:00", "unit_price": 150.0, "customer_id": "C0389", "customer_city": "Pune", "customer_name": "Arjun Mehta", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.500133	t
139	ORDFA8737193D	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDFA8737193D", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-28T21:14:00", "unit_price": 220.0, "customer_id": "C0162", "customer_city": "Pune", "customer_name": "Priya Patil", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.501992	t
140	ORDA13A496B3B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA13A496B3B", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-08-11T17:23:00", "unit_price": 150.0, "customer_id": "C0124", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.503758	t
141	ORD3B1F37F32C	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD3B1F37F32C", "quantity": 2, "item_name": "Raita", "order_time": "2026-09-18T08:00:00", "unit_price": 40.0, "customer_id": "C0363", "customer_city": "Pune", "customer_name": "Rohan Desai", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.505642	t
142	ORD5911F9A2C7	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD5911F9A2C7", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-07-17T19:19:00", "unit_price": 190.0, "customer_id": "C0337", "customer_city": "Mumbai", "customer_name": "Neha Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.507297	t
143	ORD0BC4EF93E4	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD0BC4EF93E4", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-09-05T13:56:00", "unit_price": 40.0, "customer_id": "C0360", "customer_city": "Pune", "customer_name": "Pooja Sharma", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.509112	t
144	ORD5FE37322CF	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5FE37322CF", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-07-30T08:37:00", "unit_price": 260.0, "customer_id": "C0020", "customer_city": "Mumbai", "customer_name": "Sahil Joshi", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.510576	t
145	ORDB9CB06E4A1	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORDB9CB06E4A1", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-08-15T19:04:00", "unit_price": 180.0, "customer_id": "C0349", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.512475	t
146	ORDE98AAAAA6D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE98AAAAA6D", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-10-08T19:55:00", "unit_price": 260.0, "customer_id": "C0197", "customer_city": "Mumbai", "customer_name": "Sneha Sharma", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.514072	t
147	ORD024AF702B2	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD024AF702B2", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-08T19:59:00", "unit_price": 380.0, "customer_id": "C0315", "customer_city": "Thane", "customer_name": "Vikram Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.515873	t
148	ORD38A6FC9F78	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD38A6FC9F78", "quantity": 3, "item_name": "Raita", "order_time": "2026-08-19T17:20:00", "unit_price": 40.0, "customer_id": "C0269", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.517913	t
149	ORD4E721583E0	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD4E721583E0", "quantity": 1, "item_name": "French Fries", "order_time": "2026-09-15T16:43:00", "unit_price": 90.0, "customer_id": "C0253", "customer_city": "Pune", "customer_name": "Neha Nair", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.519817	t
150	ORD1F9EBE4F5F	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1F9EBE4F5F", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-09-26T17:03:00", "unit_price": 180.0, "customer_id": "C0338", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.521509	t
151	ORDEB2A5D1020	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORDEB2A5D1020", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-10-08T22:00:00", "unit_price": 350.0, "customer_id": "C0312", "customer_city": "Thane", "customer_name": "Vikram Sharma", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.523223	t
152	ORDC72CE025E9	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDC72CE025E9", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-07-18T14:52:00", "unit_price": 340.0, "customer_id": "C0012", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.524792	t
153	ORD5CBC9C2BE3	{"status": "PLACED", "cuisine": "Chinese", "order_id": "ORD5CBC9C2BE3", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-08-27T08:54:00", "unit_price": 210.0, "customer_id": "C0266", "customer_city": "Mumbai", "customer_name": "Neha Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.526334	t
154	ORD117A49CEFB	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD117A49CEFB", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-14T16:01:00", "unit_price": 55.0, "customer_id": "C0347", "customer_city": "Thane", "customer_name": "Sahil Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.528128	t
155	ORDEF9D59D3D0	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDEF9D59D3D0", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-07-24T08:58:00", "unit_price": 80.0, "customer_id": "C0363", "customer_city": "Pune", "customer_name": "Rohan Desai", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.529648	t
156	ORD988F57DF06	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD988F57DF06", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-07T14:01:00", "unit_price": 380.0, "customer_id": "C0103", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.531238	t
157	ORD078AECC7E6	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD078AECC7E6", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-09-06T14:27:00", "unit_price": 40.0, "customer_id": "C0234", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.532517	t
158	ORD67343DED6D	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD67343DED6D", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-27T14:41:00", "unit_price": 280.0, "customer_id": "C0282", "customer_city": "MUMBAI", "customer_name": "  neha khan ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.534608	t
159	ORD9B0D1AF746	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9B0D1AF746", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-09-13T22:02:00", "unit_price": 380.0, "customer_id": "C0102", "customer_city": "Thane", "customer_name": "Anjali Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.536144	t
160	ORD4103BE1E52	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4103BE1E52", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-10-05T20:48:00", "unit_price": -320.0, "customer_id": "C0161", "customer_city": "Mumbai", "customer_name": "Rohan Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.538259	t
161	ORD56EF84E893	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD56EF84E893", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-07-28T21:51:00", "unit_price": 190.0, "customer_id": "C0256", "customer_city": "Mumbai", "customer_name": "Neha Desai", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.539716	t
162	ORD648841ADF5	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD648841ADF5", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-08-08T20:17:00", "unit_price": 280.0, "customer_id": "C0036", "customer_city": "Mumbai", "customer_name": "Rohan Sharma", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.541651	t
163	ORD7CED31517A	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORD7CED31517A", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-07-19T20:44:00", "unit_price": 320.0, "customer_id": "C0226", "customer_city": "Mumbai", "customer_name": "Sahil Iyer", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.543055	t
164	ORD7854474E4F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD7854474E4F", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-09-28T17:05:00", "unit_price": 40.0, "customer_id": "C0073", "customer_city": "Pune", "customer_name": "Arjun Patil", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.544348	t
165	ORDECEB49511A	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDECEB49511A", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-08-02T16:27:00", "unit_price": 140.0, "customer_id": "C0100", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.545654	t
166	ORD9169DE2917	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD9169DE2917", "quantity": 3, "item_name": "Masala Dosa", "order_time": "2026-10-09T21:11:00", "unit_price": 110.0, "customer_id": "C0209", "customer_city": "Pune", "customer_name": "Vikram Kulkarni", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.547536	t
167	ORDDDEEA32A12	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDDDEEA32A12", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-09-05T19:10:00", "unit_price": 120.0, "customer_id": "C0245", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.548843	t
168	ORDAB22D474EC	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDAB22D474EC", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-08-02T21:03:00", "unit_price": 80.0, "customer_id": "C0140", "customer_city": "PUNE", "customer_name": "  priya sharma ", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.550393	t
169	ORD14C22D90C9	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD14C22D90C9", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-20T20:15:00", "unit_price": 340.0, "customer_id": "C0277", "customer_city": "Thane", "customer_name": "Anjali Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.552389	t
170	ORD8959FDBEF6	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD8959FDBEF6", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-07-24T12:45:00", "unit_price": 380.0, "customer_id": "C0313", "customer_city": "Thane", "customer_name": "Aarav Mehta", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.5539	t
171	ORD4E988B9E75	{"status": "CANCELLED", "cuisine": "Italian", "order_id": "ORD4E988B9E75", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-27T16:35:00", "unit_price": 280.0, "customer_id": "C0059", "customer_city": "Mumbai", "customer_name": "Pooja Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.555456	t
172	ORD4ABA4B7449	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4ABA4B7449", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-08-29T20:27:00", "unit_price": 260.0, "customer_id": "C0136", "customer_city": "Mumbai", "customer_name": "Neha Joshi", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.556781	t
173	ORDFCC09BF293	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDFCC09BF293", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-09-18T20:20:00", "unit_price": 190.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.558101	t
174	ORDE382119614	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE382119614", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-09-10T13:41:00", "unit_price": 150.0, "customer_id": "C0001", "customer_city": "THANE", "customer_name": "  pooja kulkarni ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.559662	t
175	ORD65E5AF984B	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD65E5AF984B", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-19T13:25:00", "unit_price": 280.0, "customer_id": "C0053", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.561185	t
176	ORD5643F96569	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD5643F96569", "quantity": 3, "item_name": "Raita", "order_time": "2026-07-30T20:41:00", "unit_price": 40.0, "customer_id": "C0270", "customer_city": "Pune", "customer_name": "Arjun Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.562647	t
177	ORDC79B58951E	{"status": "PLACED", "cuisine": "Japanese", "order_id": "ORDC79B58951E", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-16T20:47:00", "unit_price": 150.0, "customer_id": "C0312", "customer_city": "Thane", "customer_name": "Vikram Sharma", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.563995	t
178	ORDE8CF7DC8F9	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE8CF7DC8F9", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-10-04T21:47:00", "unit_price": 55.0, "customer_id": "C0125", "customer_city": "Thane", "customer_name": "Aarav Mehta", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.565843	t
179	ORD88B7871999	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD88B7871999", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-08-21T12:40:00", "unit_price": 220.0, "customer_id": "C0375", "customer_city": "Mumbai", "customer_name": "Vikram Patil", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.567587	t
180	ORD16ACC826A0	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD16ACC826A0", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-09-19T09:19:00", "unit_price": 190.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Riya Desai", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.569306	t
181	ORD2188DF6A5B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2188DF6A5B", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-06T21:53:00", "unit_price": 350.0, "customer_id": "C0274", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.571264	t
182	ORD257866985E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD257866985E", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-09-27T12:27:00", "unit_price": 350.0, "customer_id": "C0122", "customer_city": "Thane", "customer_name": "Sneha Desai", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.572743	t
183	ORDB6CBA7931E	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB6CBA7931E", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-10-07T19:27:00", "unit_price": 220.0, "customer_id": "C0078", "customer_city": "Pune", "customer_name": "Kabir Kulkarni", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.574073	t
184	ORD955BFFBFBF	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD955BFFBFBF", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-07-19T09:39:00", "unit_price": 80.0, "customer_id": "C0392", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.575659	t
185	ORDFDDACD8FAC	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDFDDACD8FAC", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-10-10T16:03:00", "unit_price": 55.0, "customer_id": "C0339", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.577262	t
186	ORDB8F80EBF59	{"status": "PLACED", "cuisine": "Hyderabadi", "order_id": "ORDB8F80EBF59", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-10-02T21:41:00", "unit_price": 280.0, "customer_id": "C0249", "customer_city": "PUNE", "customer_name": "  kabir khan ", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.57874	t
187	ORD3E4AB708CE	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORD3E4AB708CE", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-08-11T13:27:00", "unit_price": 110.0, "customer_id": "C0148", "customer_city": "Pune", "customer_name": "Aarav Mehta", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.580253	t
188	ORD7CEEAE4CCA	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7CEEAE4CCA", "quantity": 4, "item_name": "Butter Chicken", "order_time": "2026-07-23T08:41:00", "unit_price": 320.0, "customer_id": "C0070", "customer_city": "Mumbai", "customer_name": "Vikram Mehta", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.582067	t
189	ORD09E5F92183	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD09E5F92183", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-08-20T12:43:00", "unit_price": 55.0, "customer_id": "C0077", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.58345	t
190	ORDD7AA5A6D51	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDD7AA5A6D51", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-09-16T17:04:00", "unit_price": 140.0, "customer_id": "C0367", "customer_city": "Pune", "customer_name": "Neha Nair", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.585013	t
191	ORD451A4D930E	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD451A4D930E", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-09-22T17:32:00", "unit_price": 180.0, "customer_id": "C0258", "customer_city": "Mumbai", "customer_name": "Neha Desai", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.586565	t
192	ORDEC12A67D40	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDEC12A67D40", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-09T21:14:00", "unit_price": 120.0, "customer_id": "C0380", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.588355	t
193	ORD89CE3C8E76	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD89CE3C8E76", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-09-25T22:57:00", "unit_price": 380.0, "customer_id": "C0092", "customer_city": "Thane", "customer_name": "Sahil Patil", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.589882	t
194	ORD81FA5EAD63	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD81FA5EAD63", "quantity": 3, "item_name": "Pasta Alfredo", "order_time": "2026-07-28T16:47:00", "unit_price": 280.0, "customer_id": "C0084", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.59137	t
195	ORD52094184C0	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD52094184C0", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-09-05T17:31:00", "unit_price": 210.0, "customer_id": "C0366", "customer_city": "Mumbai", "customer_name": "Sneha Khan", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.592831	t
196	ORDA468F901C1	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDA468F901C1", "quantity": 3, "item_name": "Raita", "order_time": "2026-07-16T19:37:00", "unit_price": 40.0, "customer_id": "C0017", "customer_city": "Pune", "customer_name": "Vikram Desai", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.59448	t
197	ORD40FE7AC855	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD40FE7AC855", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-07-18T14:24:00", "unit_price": 299.0, "customer_id": "C0009", "customer_city": "MUMBAI", "customer_name": "  neha singh ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.596046	t
198	ORD5EB460B149	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5EB460B149", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-10-04T20:31:00", "unit_price": 55.0, "customer_id": "C0023", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.59765	t
199	ORDB322A1C731	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB322A1C731", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-08-21T09:26:00", "unit_price": 55.0, "customer_id": "C0031", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.598997	t
200	ORDB615EE3B4C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB615EE3B4C", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-09-13T13:15:00", "unit_price": 180.0, "customer_id": "C0380", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.600312	t
201	ORD8773664DAB	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8773664DAB", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-08-04T21:41:00", "unit_price": 320.0, "customer_id": "C0286", "customer_city": "Mumbai", "customer_name": "Riya Nair", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.60246	t
202	ORDB96214E23E	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB96214E23E", "quantity": 3, "item_name": "Raita", "order_time": "2026-07-28T20:36:00", "unit_price": 40.0, "customer_id": "C0223", "customer_city": "PUNE", "customer_name": "  arjun sharma ", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.604439	t
203	ORD689E47E7D4	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD689E47E7D4", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-21T21:10:00", "unit_price": 150.0, "customer_id": "C0145", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.606235	t
204	ORDBA3D0066EC	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDBA3D0066EC", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-10-05T22:13:00", "unit_price": 299.0, "customer_id": "C0067", "customer_city": "Mumbai", "customer_name": "Aarav Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.607785	t
205	ORD4C66BC699C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD4C66BC699C", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-10T14:02:00", "unit_price": 350.0, "customer_id": "C0312", "customer_city": "Thane", "customer_name": "Vikram Sharma", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.60922	t
206	ORDFCFDB005A1	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORDFCFDB005A1", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-18T22:10:00", "unit_price": 55.0, "customer_id": "C0068", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.610793	t
207	ORD6D79C92B00	{"status": "PLACED", "cuisine": "Fast Food", "order_id": "ORD6D79C92B00", "quantity": 4, "item_name": "French Fries", "order_time": "2026-08-26T14:39:00", "unit_price": 90.0, "customer_id": "C0153", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.612636	t
208	ORDA0AB8C8D07	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA0AB8C8D07", "quantity": 4, "item_name": "Idli Sambar", "order_time": "2026-08-20T09:50:00", "unit_price": 80.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Vikram Patil", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.614005	t
209	ORD31D1BE0157	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD31D1BE0157", "quantity": 4, "item_name": "French Fries", "order_time": "2026-08-08T09:57:00", "unit_price": 90.0, "customer_id": "C0369", "customer_city": "Pune", "customer_name": "Pooja Desai", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.615964	t
210	ORDEF596E308F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDEF596E308F", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-08-05T14:23:00", "unit_price": 380.0, "customer_id": "C0350", "customer_city": "Thane", "customer_name": "Riya Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.617764	t
211	ORD5CEBD05566	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5CEBD05566", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-14T14:59:00", "unit_price": 340.0, "customer_id": "C0352", "customer_city": "Thane", "customer_name": "Kabir Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.619983	t
212	ORD887BBE35FF	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD887BBE35FF", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-08-02T20:15:00", "unit_price": 80.0, "customer_id": "C0231", "customer_city": "Pune", "customer_name": "Anjali Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.62181	t
213	ORD553BD4E999	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD553BD4E999", "quantity": 3, "item_name": "Raita", "order_time": "2026-07-24T08:24:00", "unit_price": 40.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Arjun Patil", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.623657	t
214	ORD97B7EBA034	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD97B7EBA034", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-07-17T17:26:00", "unit_price": 110.0, "customer_id": "C0281", "customer_city": "Pune", "customer_name": "Vikram Singh", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.62523	t
215	ORD24AEAFEB48	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD24AEAFEB48", "quantity": 1, "item_name": "Masala Dosa", "order_time": "2026-07-17T16:56:00", "unit_price": 110.0, "customer_id": "C0290", "customer_city": "Pune", "customer_name": "Rohan Khan", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.626958	t
216	ORD12F4A729E2	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD12F4A729E2", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-07-17T09:19:00", "unit_price": 40.0, "customer_id": "C0054", "customer_city": "Pune", "customer_name": "Vikram Desai", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.628408	t
217	ORD424F271447	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORD424F271447", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-09-22T17:52:00", "unit_price": 380.0, "customer_id": "C0357", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.63012	t
218	ORDC8C2D90863	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC8C2D90863", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-08-13T19:22:00", "unit_price": 220.0, "customer_id": "C0084", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.631764	t
219	ORD3CE47839E6	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORD3CE47839E6", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-08-05T12:43:00", "unit_price": 340.0, "customer_id": "C0384", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.633256	t
220	ORD6749FD7861	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD6749FD7861", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-10-08T13:15:00", "unit_price": 150.0, "customer_id": "C0212", "customer_city": "Thane", "customer_name": "Aarav Mehta", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.6349	t
221	ORDAD9828EE98	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAD9828EE98", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-09-23T14:20:00", "unit_price": 350.0, "customer_id": "C0333", "customer_city": "Thane", "customer_name": "Sahil Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.636492	t
222	ORD6EDB7AD6DD	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD6EDB7AD6DD", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-08-03T21:43:00", "unit_price": 190.0, "customer_id": "C0316", "customer_city": "Mumbai", "customer_name": "Neha Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.638561	t
223	ORD61D413BE12	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD61D413BE12", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-08-07T21:42:00", "unit_price": 220.0, "customer_id": "C0214", "customer_city": "Mumbai", "customer_name": "Pooja Joshi", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.639995	t
224	ORD9B4AAE3AF2	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD9B4AAE3AF2", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-07-14T14:01:00", "unit_price": 280.0, "customer_id": "C0055", "customer_city": "Mumbai", "customer_name": "Vikram Mehta", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.641608	t
225	ORDE00FD47938	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE00FD47938", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-07-17T13:53:00", "unit_price": 350.0, "customer_id": "C0342", "customer_city": "Thane", "customer_name": "Sneha Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.643211	t
226	ORD032394ED6F	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD032394ED6F", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-09-06T21:20:00", "unit_price": 220.0, "customer_id": "C0054", "customer_city": "Pune", "customer_name": "Vikram Desai", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.644679	t
227	ORDB124647E58	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB124647E58", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-07-27T17:30:00", "unit_price": 220.0, "customer_id": "C0098", "customer_city": "Pune", "customer_name": "Anjali Kulkarni", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.646063	t
228	ORD1982C3121A	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD1982C3121A", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-08-01T14:38:00", "unit_price": 280.0, "customer_id": "C0079", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.647665	t
229	ORDBD27B317B8	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDBD27B317B8", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-21T21:57:00", "unit_price": 220.0, "customer_id": "C0036", "customer_city": "Mumbai", "customer_name": "Rohan Sharma", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.649273	t
230	ORD5F5C8872D2	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5F5C8872D2", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-07-25T08:56:00", "unit_price": 150.0, "customer_id": "C0208", "customer_city": "Pune", "customer_name": "Sahil Desai", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.650814	t
231	ORD855F8E1B75	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD855F8E1B75", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-08-26T09:11:00", "unit_price": 55.0, "customer_id": "C0319", "customer_city": "Thane", "customer_name": "Sahil Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.652331	t
232	ORD5E3B52CAAE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5E3B52CAAE", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-09-10T13:28:00", "unit_price": 55.0, "customer_id": "C0159", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.654127	t
233	ORD9CA999DE00	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD9CA999DE00", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-10-03T14:25:00", "unit_price": 140.0, "customer_id": "C0191", "customer_city": "PUNE", "customer_name": "  pooja nair ", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.655562	t
234	ORDDCCA98E8E8	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDDCCA98E8E8", "quantity": 1, "item_name": "French Fries", "order_time": "2026-08-30T21:37:00", "unit_price": 90.0, "customer_id": "C0160", "customer_city": "Pune", "customer_name": "Kabir Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.657237	t
235	ORDBF1FD31594	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDBF1FD31594", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-03T16:29:00", "unit_price": 220.0, "customer_id": "C0242", "customer_city": "Pune", "customer_name": "Sahil Nair", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.659058	t
236	ORDC9C96BF350	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDC9C96BF350", "quantity": 1, "item_name": "Raita", "order_time": "2026-09-10T19:59:00", "unit_price": 40.0, "customer_id": "C0303", "customer_city": "Pune", "customer_name": "Sahil Patil", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.660352	t
237	ORDC69D7A46B5	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDC69D7A46B5", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-08-16T19:32:00", "unit_price": 299.0, "customer_id": "C0009", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.661893	t
238	ORD6FD702208F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD6FD702208F", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-08-31T13:28:00", "unit_price": 40.0, "customer_id": "C0224", "customer_city": "Pune", "customer_name": "Pooja Iyer", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.663336	t
239	ORD7B46E16029	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORD7B46E16029", "quantity": 3, "item_name": "Raita", "order_time": "2026-09-04T20:16:00", "unit_price": 40.0, "customer_id": "C0191", "customer_city": "Pune", "customer_name": "Pooja Nair", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.664896	t
240	ORD56D7A1E220	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD56D7A1E220", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-07-17T20:21:00", "unit_price": 299.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.666678	t
241	ORDA23E7C5019	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA23E7C5019", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-09-14T14:15:00", "unit_price": 350.0, "customer_id": "C0370", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.668163	t
242	ORD1D86BF04AE	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD1D86BF04AE", "quantity": 1, "item_name": "Masala Dosa", "order_time": "2026-07-18T14:15:00", "unit_price": 110.0, "customer_id": "C0075", "customer_city": "Pune", "customer_name": "Pooja Joshi", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.669658	t
243	ORDD399C97CF6	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDD399C97CF6", "quantity": 2, "item_name": "Raita", "order_time": "2026-09-04T20:44:00", "unit_price": 40.0, "customer_id": "C0389", "customer_city": "Pune", "customer_name": "Arjun Mehta", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.671749	t
244	ORD958F493AFD	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD958F493AFD", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-10-10T20:50:00", "unit_price": 40.0, "customer_id": "C0184", "customer_city": "Pune", "customer_name": "Sahil Kulkarni", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.673184	t
245	ORD2839214D6C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD2839214D6C", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-08-20T13:09:00", "unit_price": 190.0, "customer_id": "C0276", "customer_city": "Mumbai", "customer_name": "Arjun Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.674517	t
246	ORD171337D55C	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD171337D55C", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-09-27T13:03:00", "unit_price": 80.0, "customer_id": "C0030", "customer_city": "Pune", "customer_name": "Riya Patil", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.675796	t
247	ORD14C85DF544	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD14C85DF544", "quantity": 4, "item_name": "Raita", "order_time": "2026-07-23T22:31:00", "unit_price": 40.0, "customer_id": "C0325", "customer_city": "Pune", "customer_name": "Pooja Mehta", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.677473	t
248	ORDD4A0BF0D04	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDD4A0BF0D04", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-07-26T13:49:00", "unit_price": -80.0, "customer_id": "C0057", "customer_city": "Pune", "customer_name": "Rohan Joshi", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.678856	t
249	ORDE6B14A6F5F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE6B14A6F5F", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-01T21:12:00", "unit_price": 150.0, "customer_id": "C0378", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.680664	t
250	ORD2F1C7B1FEC	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD2F1C7B1FEC", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-08-14T09:03:00", "unit_price": 120.0, "customer_id": "C0282", "customer_city": "MUMBAI", "customer_name": "  neha khan ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.682083	t
251	ORD9974E70D70	{"status": "CANCELLED", "cuisine": "Italian", "order_id": "ORD9974E70D70", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-09-06T20:47:00", "unit_price": 120.0, "customer_id": "C0318", "customer_city": "Mumbai", "customer_name": "Arjun Sharma", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.683566	t
252	ORD2A515A23E4	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2A515A23E4", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-07-30T09:35:00", "unit_price": 150.0, "customer_id": "C0135", "customer_city": "Thane", "customer_name": "Rohan Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.685269	t
253	ORD54C867FDA0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD54C867FDA0", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-07-21T13:26:00", "unit_price": 250.0, "customer_id": "C0034", "customer_city": "Thane", "customer_name": "Arjun Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.686893	t
254	ORD7AA6DE29B0	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD7AA6DE29B0", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-07-25T19:34:00", "unit_price": 210.0, "customer_id": "C0359", "customer_city": "Mumbai", "customer_name": "Sneha Joshi", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.688863	t
255	ORDFB773FA1D3	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDFB773FA1D3", "quantity": 3, "item_name": "Butter Chicken", "order_time": "2026-09-18T17:54:00", "unit_price": 320.0, "customer_id": "C0044", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.690345	t
256	ORD7BAF7E921A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD7BAF7E921A", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-07-21T20:29:00", "unit_price": 380.0, "customer_id": "C0386", "customer_city": "Thane", "customer_name": "Vikram Khan", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.692187	t
257	ORD70B406F7D5	{"status": "PLACED", "cuisine": "Chinese", "order_id": "ORD70B406F7D5", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-25T13:34:00", "unit_price": 180.0, "customer_id": "C0084", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.693834	t
258	ORD23FC8F1D51	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD23FC8F1D51", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-09-11T21:53:00", "unit_price": 120.0, "customer_id": "C0337", "customer_city": "MUMBAI", "customer_name": "  neha nair ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.695725	t
259	ORD3006B1D12E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3006B1D12E", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-10-06T09:56:00", "unit_price": 350.0, "customer_id": "C0049", "customer_city": "Thane", "customer_name": "Pooja Patil", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.697571	t
260	ORDEA920A68CB	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDEA920A68CB", "quantity": 3, "item_name": "Chicken Biryani", "order_time": "2026-08-05T22:02:00", "unit_price": 280.0, "customer_id": "C0100", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.699365	t
261	ORDB5D2CFACB1	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB5D2CFACB1", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-09-03T17:29:00", "unit_price": 280.0, "customer_id": "C0017", "customer_city": "Pune", "customer_name": "Vikram Desai", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.701206	t
262	ORDC15566E66D	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDC15566E66D", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-08-05T21:35:00", "unit_price": 210.0, "customer_id": "C0065", "customer_city": "Mumbai", "customer_name": "Priya Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.703282	t
263	ORDB21F8894DA	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB21F8894DA", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-07-14T14:56:00", "unit_price": 320.0, "customer_id": "C0344", "customer_city": "MUMBAI", "customer_name": "  kabir patil ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.705265	t
264	ORD73C7AFD923	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD73C7AFD923", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-13T17:42:00", "unit_price": 250.0, "customer_id": "C0086", "customer_city": "THANE", "customer_name": "  sahil mehta ", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.707326	t
265	ORD9F2DACBBEE	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9F2DACBBEE", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-27T20:39:00", "unit_price": 150.0, "customer_id": "C0218", "customer_city": "Thane", "customer_name": "Aarav Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.71035	t
266	ORD634C47C015	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD634C47C015", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-07-31T20:04:00", "unit_price": 150.0, "customer_id": null, "customer_city": "THANE", "customer_name": "  rohan sharma ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.712918	t
267	ORD9674E79C13	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9674E79C13", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-10-01T13:41:00", "unit_price": 150.0, "customer_id": "C0146", "customer_city": "Thane", "customer_name": "Riya Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.714663	t
268	ORDB719BEB888	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB719BEB888", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-08-29T17:28:00", "unit_price": 280.0, "customer_id": "C0210", "customer_city": "Pune", "customer_name": "Sneha Nair", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.716142	t
269	ORD8D1AC0C940	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8D1AC0C940", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-07-30T20:46:00", "unit_price": 60.0, "customer_id": "C0053", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.717915	t
270	ORD39F9F719A0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD39F9F719A0", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-08-30T21:57:00", "unit_price": 55.0, "customer_id": "C0400", "customer_city": "Thane", "customer_name": "Aarav Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.719636	t
271	ORD59A189084D	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD59A189084D", "quantity": 0, "item_name": "Veg Biryani", "order_time": "2026-08-03T14:09:00", "unit_price": 220.0, "customer_id": "C0189", "customer_city": "PUNE", "customer_name": "  aarav patil ", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.721345	t
272	ORDAD9FCA2F39	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAD9FCA2F39", "quantity": 1, "item_name": "Paneer Tikka", "order_time": "2026-08-20T17:00:00", "unit_price": 260.0, "customer_id": "C0019", "customer_city": "Mumbai", "customer_name": "Kabir Khan", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.723052	t
273	ORD771318B0CF	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD771318B0CF", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-07T22:43:00", "unit_price": 380.0, "customer_id": "C0228", "customer_city": "Thane", "customer_name": "Sneha Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.724669	t
274	ORD76037BCA1C	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD76037BCA1C", "quantity": 2, "item_name": "Chicken Biryani", "order_time": "2026-07-26T21:30:00", "unit_price": 280.0, "customer_id": "C0348", "customer_city": "Pune", "customer_name": "Anjali Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.726228	t
275	ORDA7993AF069	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDA7993AF069", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-08-16T17:21:00", "unit_price": 280.0, "customer_id": "C0388", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.72782	t
276	ORD9372CAC2DE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9372CAC2DE", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-08-20T13:06:00", "unit_price": 220.0, "customer_id": "C0132", "customer_city": "Mumbai", "customer_name": "Rohan Mehta", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.729617	t
277	ORD5FA1E36B5A	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5FA1E36B5A", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-09-11T08:55:00", "unit_price": 140.0, "customer_id": "C0076", "customer_city": "Pune", "customer_name": "Rohan Khan", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.731027	t
278	ORD34F88F6F5F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD34F88F6F5F", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-08-12T21:34:00", "unit_price": 40.0, "customer_id": "C0209", "customer_city": "Pune", "customer_name": "Vikram Kulkarni", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.732544	t
279	ORD701BC8F8AC	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD701BC8F8AC", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-10-04T17:04:00", "unit_price": 40.0, "customer_id": "C0008", "customer_city": "Pune", "customer_name": "Sneha Sharma", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.734257	t
280	ORD49860A6C71	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD49860A6C71", "quantity": 4, "item_name": "Raita", "order_time": "2026-07-27T08:38:00", "unit_price": 40.0, "customer_id": "C0248", "customer_city": "Pune", "customer_name": "Rohan Mehta", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.735759	t
281	ORDEA87587491	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEA87587491", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-09-08T20:03:00", "unit_price": 55.0, "customer_id": "C0141", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.737509	t
282	ORD96ED264D3A	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD96ED264D3A", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-08-22T09:47:00", "unit_price": 210.0, "customer_id": "C0368", "customer_city": "MUMBAI", "customer_name": "  riya desai ", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.738869	t
283	ORD7DCEC333F9	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD7DCEC333F9", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-09-05T13:22:00", "unit_price": 180.0, "customer_id": "C0287", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.740416	t
284	ORD6576C6B8F1	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD6576C6B8F1", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-08-11T21:47:00", "unit_price": 150.0, "customer_id": "C0052", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.741783	t
285	ORDE0BCA3DF4F	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE0BCA3DF4F", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-08-28T20:23:00", "unit_price": 190.0, "customer_id": "C0299", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.743348	t
286	ORDA635B610EC	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA635B610EC", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-08-30T13:42:00", "unit_price": 250.0, "customer_id": "C0205", "customer_city": "Thane", "customer_name": "Sneha Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.744862	t
287	ORD1855B7B2E2	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1855B7B2E2", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-08-28T19:11:00", "unit_price": 180.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.74647	t
288	ORD1BA485CC22	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD1BA485CC22", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-08-13T21:25:00", "unit_price": 150.0, "customer_id": "C0321", "customer_city": "Thane", "customer_name": "Kabir Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.74794	t
289	ORD4F518BC568	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4F518BC568", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-07-20T16:58:00", "unit_price": 340.0, "customer_id": "C0313", "customer_city": "Thane", "customer_name": "Aarav Mehta", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.749538	t
290	ORD6F25FA8082	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD6F25FA8082", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-07-28T22:46:00", "unit_price": 180.0, "customer_id": "C0279", "customer_city": "Mumbai", "customer_name": "Rohan Singh", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.751079	t
291	ORDBD45247A76	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDBD45247A76", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-06T19:12:00", "unit_price": 150.0, "customer_id": "C0339", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.752602	t
292	ORDD0668D489A	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDD0668D489A", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-08-31T22:09:00", "unit_price": 299.0, "customer_id": "C0385", "customer_city": "MUMBAI", "customer_name": "  rohan singh ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.754201	t
293	ORD3076C13F58	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD3076C13F58", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-07-16T14:10:00", "unit_price": 210.0, "customer_id": "C0197", "customer_city": "Mumbai", "customer_name": "Sneha Sharma", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.755777	t
294	ORDDFB271506A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDDFB271506A", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-07-25T22:33:00", "unit_price": 350.0, "customer_id": "C0352", "customer_city": "Thane", "customer_name": "Kabir Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.757253	t
295	ORDEAF6C6DC1A	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDEAF6C6DC1A", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-10-08T14:54:00", "unit_price": 150.0, "customer_id": "C0054", "customer_city": "Pune", "customer_name": "Vikram Desai", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.758843	t
296	ORD4447695595	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4447695595", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-25T21:02:00", "unit_price": 55.0, "customer_id": "C0049", "customer_city": "Thane", "customer_name": "Pooja Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.760398	t
297	ORD976DB40AB1	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD976DB40AB1", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-09-25T19:41:00", "unit_price": 190.0, "customer_id": "C0235", "customer_city": "Mumbai", "customer_name": "Anjali Desai", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.761942	t
298	ORDC65340346A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC65340346A", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-09-15T12:29:00", "unit_price": 250.0, "customer_id": "C0113", "customer_city": "Thane", "customer_name": "Rohan Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.763162	t
299	ORD892F9180F9	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD892F9180F9", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-10-09T21:30:00", "unit_price": 40.0, "customer_id": "C0134", "customer_city": "Pune", "customer_name": "Aarav Patil", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.764748	t
300	ORD8F5C2E6BB8	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD8F5C2E6BB8", "quantity": 3, "item_name": "French Fries", "order_time": "2026-08-15T21:45:00", "unit_price": 90.0, "customer_id": "C0367", "customer_city": "Pune", "customer_name": "Neha Nair", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.766226	t
301	ORD7D4E77C43F	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD7D4E77C43F", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-07-16T22:01:00", "unit_price": 180.0, "customer_id": "C0282", "customer_city": "Mumbai", "customer_name": "Neha Khan", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.76772	t
302	ORD870DC56066	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD870DC56066", "quantity": 2, "item_name": "Garlic Naan", "order_time": "2026-08-07T20:41:00", "unit_price": 60.0, "customer_id": "C0055", "customer_city": "Mumbai", "customer_name": "Vikram Mehta", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.769614	t
303	ORDB0BDF95BAA	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORDB0BDF95BAA", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-08-30T21:57:00", "unit_price": 350.0, "customer_id": "C0329", "customer_city": "Thane", "customer_name": "Neha Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.771061	t
304	ORDCE0C2704EF	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDCE0C2704EF", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-10-06T20:34:00", "unit_price": 380.0, "customer_id": "C0023", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.772601	t
305	ORDF7CA009B6D	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDF7CA009B6D", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-09-16T08:19:00", "unit_price": 55.0, "customer_id": "C0362", "customer_city": "Thane", "customer_name": "Anjali Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.774141	t
306	ORD2F3637B6BC	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD2F3637B6BC", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-10-07T20:30:00", "unit_price": 80.0, "customer_id": "C0238", "customer_city": "Pune", "customer_name": "Arjun Kulkarni", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.775859	t
307	ORD117A49CEFB	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD117A49CEFB", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-14T16:01:00", "unit_price": 55.0, "customer_id": "C0347", "customer_city": "Thane", "customer_name": "Sahil Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.777389	t
308	ORDF6D19FA0BF	{"status": "CANCELLED", "cuisine": "Italian", "order_id": "ORDF6D19FA0BF", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-09-05T17:04:00", "unit_price": 299.0, "customer_id": "C0301", "customer_city": "Mumbai", "customer_name": "Kabir Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.778942	t
309	ORD6AF36EB383	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6AF36EB383", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-27T20:32:00", "unit_price": 340.0, "customer_id": "C0315", "customer_city": "Thane", "customer_name": "Vikram Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.78057	t
310	ORD8152B60D88	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD8152B60D88", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-09-04T13:03:00", "unit_price": 150.0, "customer_id": "C0387", "customer_city": "Thane", "customer_name": "Riya Desai", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.782378	t
311	ORD0A68626F15	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD0A68626F15", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-09-06T14:37:00", "unit_price": 120.0, "customer_id": "C0063", "customer_city": "Mumbai", "customer_name": "Arjun Patil", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.783602	t
312	ORD91B365FB70	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD91B365FB70", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-09-02T13:21:00", "unit_price": 220.0, "customer_id": "C0192", "customer_city": "Mumbai", "customer_name": "Sneha Iyer", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.785016	t
313	ORDA2FC58C78A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA2FC58C78A", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-09-01T14:56:00", "unit_price": 55.0, "customer_id": "C0298", "customer_city": "Thane", "customer_name": "Priya Singh", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.786539	t
314	ORD3A6D26A2C6	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORD3A6D26A2C6", "quantity": 4, "item_name": "Raita", "order_time": "2026-09-09T09:43:00", "unit_price": 40.0, "customer_id": "C0118", "customer_city": "Pune", "customer_name": "Aarav Desai", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.788183	t
315	ORDD7E073346A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD7E073346A", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-08-22T13:04:00", "unit_price": 320.0, "customer_id": "C0280", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.790058	t
316	ORD3CAE130E03	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD3CAE130E03", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-03T08:31:00", "unit_price": 180.0, "customer_id": "C0126", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.791663	t
317	ORD3509DDCAD7	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3509DDCAD7", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-07-13T13:42:00", "unit_price": 340.0, "customer_id": "C0145", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.79329	t
318	ORD6A14EAF494	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6A14EAF494", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-08-06T21:05:00", "unit_price": 260.0, "customer_id": "C0286", "customer_city": "Mumbai", "customer_name": "Riya Nair", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.794958	t
319	ORD024391C636	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD024391C636", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-07-16T08:11:00", "unit_price": 380.0, "customer_id": "C0137", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.796694	t
320	ORDD5B5DCEACC	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDD5B5DCEACC", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-09-21T17:51:00", "unit_price": 140.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Anjali Kulkarni", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.798308	t
321	ORDF5DC9E2BFD	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDF5DC9E2BFD", "quantity": 1, "item_name": "French Fries", "order_time": "2026-07-29T12:54:00", "unit_price": 90.0, "customer_id": "C0323", "customer_city": "PUNE", "customer_name": "  rohan nair ", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.79952	t
322	ORD89F1DEE622	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD89F1DEE622", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-08-17T13:02:00", "unit_price": 350.0, "customer_id": "C0167", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.800955	t
323	ORDAF67A95944	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAF67A95944", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-07-17T16:59:00", "unit_price": 60.0, "customer_id": "C0180", "customer_city": "Mumbai", "customer_name": "Sahil Iyer", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.80274	t
324	ORD1F2B9FADA5	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1F2B9FADA5", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-07-21T08:14:00", "unit_price": 210.0, "customer_id": "C0279", "customer_city": "Mumbai", "customer_name": "Rohan Singh", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.804451	t
325	ORD9F24F6B916	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORD9F24F6B916", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-08-25T21:55:00", "unit_price": 250.0, "customer_id": "C0298", "customer_city": "Thane", "customer_name": "Priya Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.806097	t
326	ORD522DCAB7C4	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD522DCAB7C4", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-07T14:08:00", "unit_price": 150.0, "customer_id": "C0248", "customer_city": "Pune", "customer_name": "Rohan Mehta", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.807847	t
327	ORDF9F3DEB1D9	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDF9F3DEB1D9", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-08-22T13:51:00", "unit_price": 180.0, "customer_id": "C0070", "customer_city": "Mumbai", "customer_name": "Vikram Mehta", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.809346	t
328	ORD1F27C2C6F7	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD1F27C2C6F7", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-09-08T21:48:00", "unit_price": 320.0, "customer_id": "C0349", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.810833	t
329	ORDB402EED28A	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB402EED28A", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-10-07T21:00:00", "unit_price": 190.0, "customer_id": "C0188", "customer_city": "Mumbai", "customer_name": "Priya Joshi", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.812307	t
330	ORDFBC22C7A27	{"status": "PLACED", "cuisine": "Chinese", "order_id": "ORDFBC22C7A27", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-07-28T21:18:00", "unit_price": 190.0, "customer_id": "C0084", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.81416	t
331	ORDDF481E77BA	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDDF481E77BA", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-29T14:09:00", "unit_price": 150.0, "customer_id": "C0103", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.815592	t
332	ORD04EA2B5443	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD04EA2B5443", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-08-28T09:16:00", "unit_price": 120.0, "customer_id": "C0029", "customer_city": "Mumbai", "customer_name": "Sahil Desai", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.817147	t
333	ORD40631DE4C9	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD40631DE4C9", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-08-03T17:52:00", "unit_price": 190.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.818686	t
334	ORD66152D7017	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD66152D7017", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-08-22T22:28:00", "unit_price": 150.0, "customer_id": "C0073", "customer_city": "Pune", "customer_name": "Arjun Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.821079	t
335	ORD32AD8EA268	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD32AD8EA268", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-07-17T12:29:00", "unit_price": 380.0, "customer_id": "C0255", "customer_city": "Thane", "customer_name": "Vikram Mehta", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.822929	t
336	ORD34A98FF28A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD34A98FF28A", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-20T19:46:00", "unit_price": 250.0, "customer_id": "C0205", "customer_city": "Thane", "customer_name": "Sneha Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.824657	t
337	ORD59D6BCB90B	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD59D6BCB90B", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-10-01T09:21:00", "unit_price": 190.0, "customer_id": "C0287", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.827	t
338	ORD5F00C378B0	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5F00C378B0", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-09-11T21:50:00", "unit_price": 140.0, "customer_id": "C0252", "customer_city": "Pune", "customer_name": "Pooja Patil", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.829161	t
339	ORDB5612D5260	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB5612D5260", "quantity": 4, "item_name": "Butter Chicken", "order_time": "2026-08-18T13:31:00", "unit_price": 320.0, "customer_id": "C0044", "customer_city": "MUMBAI", "customer_name": "  rohan patil ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.830983	t
340	ORD433D1529EB	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD433D1529EB", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-05T16:10:00", "unit_price": 150.0, "customer_id": "C0244", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.832526	t
341	ORD08F10FF020	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD08F10FF020", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-30T21:03:00", "unit_price": 340.0, "customer_id": "C0313", "customer_city": "Thane", "customer_name": "Aarav Mehta", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.834145	t
342	ORD3F5209A074	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3F5209A074", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-09-21T12:52:00", "unit_price": 350.0, "customer_id": "C0345", "customer_city": "THANE", "customer_name": "  neha desai ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.83591	t
343	ORDF92B7D4B96	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORDF92B7D4B96", "quantity": 3, "item_name": "Raita", "order_time": "2026-08-02T17:56:00", "unit_price": 40.0, "customer_id": "C0249", "customer_city": "Pune", "customer_name": "Kabir Khan", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.837369	t
344	ORD5F3FC2DA5C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD5F3FC2DA5C", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-08-22T08:22:00", "unit_price": 299.0, "customer_id": "C0188", "customer_city": "Mumbai", "customer_name": "Priya Joshi", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.839038	t
345	ORD8CE5859BA7	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD8CE5859BA7", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-08-02T12:25:00", "unit_price": 180.0, "customer_id": "C0006", "customer_city": "Mumbai", "customer_name": "Sneha Khan", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.840658	t
346	ORD249E93DB9C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD249E93DB9C", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-08-09T21:56:00", "unit_price": 250.0, "customer_id": "C0386", "customer_city": "Thane", "customer_name": "Vikram Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.842281	t
347	ORDAD06D9099D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAD06D9099D", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-07-20T21:36:00", "unit_price": 60.0, "customer_id": "C0002", "customer_city": "Mumbai", "customer_name": "Pooja Patil", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.843882	t
348	ORDBFEF504B4D	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDBFEF504B4D", "quantity": 3, "item_name": "Chicken Biryani", "order_time": "2026-09-18T22:48:00", "unit_price": 280.0, "customer_id": "C0075", "customer_city": "Pune", "customer_name": "Pooja Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.845343	t
349	ORDA4866A95A3	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDA4866A95A3", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-09-23T14:15:00", "unit_price": 210.0, "customer_id": "C0084", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.847245	t
350	ORD57F59A926D	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD57F59A926D", "quantity": 3, "item_name": "Raita", "order_time": "2026-09-07T19:23:00", "unit_price": 40.0, "customer_id": "C0166", "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.848488	t
351	ORDEFF018285F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDEFF018285F", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-08-11T20:16:00", "unit_price": 80.0, "customer_id": "C0169", "customer_city": "Pune", "customer_name": "Pooja Kulkarni", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.849873	t
352	ORD0B64478E91	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD0B64478E91", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-07-13T13:49:00", "unit_price": 110.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Rohan Desai", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.851434	t
353	ORD96841D0D5F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD96841D0D5F", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-09-11T19:45:00", "unit_price": 140.0, "customer_id": "C0217", "customer_city": "Pune", "customer_name": "Anjali Kulkarni", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.853146	t
354	ORD5C9DE64A76	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD5C9DE64A76", "quantity": 3, "item_name": "Chicken Biryani", "order_time": "2026-10-03T14:19:00", "unit_price": 280.0, "customer_id": "C0378", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.854583	t
355	ORD091A25121F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD091A25121F", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-09-13T14:58:00", "unit_price": 80.0, "customer_id": "C0158", "customer_city": "Pune", "customer_name": "Vikram Mehta", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.855947	t
356	ORDF1B44BE16A	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDF1B44BE16A", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-10T19:09:00", "unit_price": 220.0, "customer_id": "C0186", "customer_city": "PUNE", "customer_name": "  neha singh ", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.857439	t
357	ORDFD8E3316F6	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDFD8E3316F6", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-08-10T14:11:00", "unit_price": 140.0, "customer_id": "C0041", "customer_city": "Pune", "customer_name": "Sahil Kulkarni", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.85907	t
358	ORDFAE8E313F6	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDFAE8E313F6", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-09-13T14:57:00", "unit_price": 180.0, "customer_id": "C0310", "customer_city": "Mumbai", "customer_name": "Riya Singh", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.860639	t
359	ORD6E1FED5F8A	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD6E1FED5F8A", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-06T21:00:00", "unit_price": 220.0, "customer_id": "C0076", "customer_city": "Pune", "customer_name": "Rohan Khan", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.862145	t
360	ORDEF1679AB27	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDEF1679AB27", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-07-29T14:56:00", "unit_price": 140.0, "customer_id": "C0234", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.863614	t
361	ORD75E36D6C5A	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD75E36D6C5A", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-07-15T21:00:00", "unit_price": 180.0, "customer_id": "C0375", "customer_city": "Mumbai", "customer_name": "Vikram Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.86504	t
362	ORDEF56C3F343	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEF56C3F343", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-10-03T09:21:00", "unit_price": 320.0, "customer_id": "C0079", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.866545	t
363	ORD0701DDB308	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0701DDB308", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-10-04T21:15:00", "unit_price": 340.0, "customer_id": "C0212", "customer_city": "Thane", "customer_name": "Aarav Mehta", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.868022	t
364	ORDFF9833EE17	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDFF9833EE17", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-10-03T09:51:00", "unit_price": 210.0, "customer_id": "C0065", "customer_city": "Mumbai", "customer_name": "Priya Mehta", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.869509	t
365	ORDE2CC0BBD2E	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE2CC0BBD2E", "quantity": 4, "item_name": "Pasta Alfredo", "order_time": "2026-09-04T19:04:00", "unit_price": 280.0, "customer_id": "C0368", "customer_city": "Mumbai", "customer_name": "Riya Desai", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.87096	t
366	ORD29A969FC72	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD29A969FC72", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-08-25T20:59:00", "unit_price": 340.0, "customer_id": "C0072", "customer_city": "THANE", "customer_name": "  sneha sharma ", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.872855	t
367	ORD95391A5943	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD95391A5943", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-08-05T17:28:00", "unit_price": 180.0, "customer_id": "C0039", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.874161	t
368	ORDCC91071E2F	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORDCC91071E2F", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-08-05T21:45:00", "unit_price": 180.0, "customer_id": "C0268", "customer_city": "Mumbai", "customer_name": "Arjun Patil", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.875651	t
369	ORDC2CB3C5341	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORDC2CB3C5341", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-24T20:25:00", "unit_price": 220.0, "customer_id": "C0166", "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.877267	t
370	ORDD9002408A0	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORDD9002408A0", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-31T17:40:00", "unit_price": -150.0, "customer_id": "C0277", "customer_city": "Thane", "customer_name": "Anjali Sharma", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.878649	t
371	ORD10E596EC97	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD10E596EC97", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-08-10T20:55:00", "unit_price": 250.0, "customer_id": "C0143", "customer_city": "Thane", "customer_name": "Sahil Mehta", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.880353	t
372	ORDB4DA171522	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB4DA171522", "quantity": 4, "item_name": "Raita", "order_time": "2026-08-01T09:16:00", "unit_price": 40.0, "customer_id": "C0325", "customer_city": "Pune", "customer_name": "Pooja Mehta", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.881601	t
373	ORD7D58E7C4C9	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD7D58E7C4C9", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-08-25T19:33:00", "unit_price": -110.0, "customer_id": "C0234", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.883232	t
374	ORDF5673BC0E4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF5673BC0E4", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-21T21:48:00", "unit_price": 340.0, "customer_id": "C0015", "customer_city": "Thane", "customer_name": "Rohan Nair", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.884835	t
375	ORD93BA03B3F4	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD93BA03B3F4", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-07-22T21:40:00", "unit_price": 40.0, "customer_id": "C0394", "customer_city": "Pune", "customer_name": "Neha Joshi", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.886472	t
376	ORD69E436C7D8	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD69E436C7D8", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-07T19:23:00", "unit_price": 340.0, "customer_id": "C0199", "customer_city": "Thane", "customer_name": "Priya Nair", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.887909	t
377	ORD9A2990E3C8	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD9A2990E3C8", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-09-11T17:08:00", "unit_price": 150.0, "customer_id": "C0290", "customer_city": "Pune", "customer_name": "Rohan Khan", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.889246	t
378	ORD25A762F2B7	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD25A762F2B7", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-09-19T09:16:00", "unit_price": 220.0, "customer_id": "C0325", "customer_city": "Pune", "customer_name": "Pooja Mehta", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.890898	t
379	ORD75DF9DA1F4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD75DF9DA1F4", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-08-12T08:26:00", "unit_price": 220.0, "customer_id": "C0278", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.892551	t
380	ORD9B762DF961	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD9B762DF961", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-02T21:49:00", "unit_price": 180.0, "customer_id": "C0117", "customer_city": "Mumbai", "customer_name": "Aarav Iyer", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.893805	t
381	ORD4E1D3F856B	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD4E1D3F856B", "quantity": 2, "item_name": "Raita", "order_time": "2026-08-14T20:21:00", "unit_price": 40.0, "customer_id": "C0172", "customer_city": "Pune", "customer_name": "Arjun Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.895222	t
382	ORD7B77A4178B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7B77A4178B", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-07-31T22:18:00", "unit_price": 340.0, "customer_id": "C0121", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.896928	t
383	ORD34B07C462C	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORD34B07C462C", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-08-25T13:46:00", "unit_price": 380.0, "customer_id": "C0289", "customer_city": "Thane", "customer_name": "Pooja Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.898357	t
384	ORD5004642540	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5004642540", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-09-07T21:00:00", "unit_price": 150.0, "customer_id": "C0381", "customer_city": "PUNE", "customer_name": "  sahil patil ", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.899771	t
385	ORD6FB0AA42DE	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORD6FB0AA42DE", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-08-17T21:15:00", "unit_price": 250.0, "customer_id": "C0146", "customer_city": "THANE", "customer_name": "  riya singh ", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.901396	t
386	ORD2899398817	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD2899398817", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-08-10T08:07:00", "unit_price": 190.0, "customer_id": "C0009", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.903265	t
387	ORD410C3B4882	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD410C3B4882", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-09-04T19:21:00", "unit_price": 299.0, "customer_id": "C0229", "customer_city": "Mumbai", "customer_name": "Vikram Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.904548	t
388	ORDF31A225CBE	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF31A225CBE", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-07-14T13:53:00", "unit_price": 380.0, "customer_id": "C0227", "customer_city": "THANE", "customer_name": "  priya khan ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.90578	t
389	ORD597DE13A89	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD597DE13A89", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-10-09T13:39:00", "unit_price": 260.0, "customer_id": "C0194", "customer_city": "MUMBAI", "customer_name": "  rohan sharma ", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.907255	t
390	ORDF9A75C7895	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF9A75C7895", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-07-23T09:13:00", "unit_price": 340.0, "customer_id": "C0178", "customer_city": "Thane", "customer_name": "Pooja Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.909157	t
391	ORD2F17E687CE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD2F17E687CE", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-09-26T20:04:00", "unit_price": 55.0, "customer_id": "C0077", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.91051	t
392	ORD82B8FB880A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD82B8FB880A", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-08-11T20:16:00", "unit_price": 220.0, "customer_id": "C0219", "customer_city": "Mumbai", "customer_name": "Pooja Nair", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.911743	t
393	ORDBF45F5133C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDBF45F5133C", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-09-24T16:02:00", "unit_price": 220.0, "customer_id": "C0268", "customer_city": "Mumbai", "customer_name": "Arjun Patil", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.913203	t
394	ORD746AA70212	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD746AA70212", "quantity": 2, "item_name": "French Fries", "order_time": "2026-07-25T22:30:00", "unit_price": 90.0, "customer_id": "C0393", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.915244	t
395	ORDDE76CA6C84	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDDE76CA6C84", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-07-21T16:58:00", "unit_price": 180.0, "customer_id": "C0005", "customer_city": "Mumbai", "customer_name": "Rohan Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.916883	t
396	ORD320B78C5B5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD320B78C5B5", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-07-30T13:42:00", "unit_price": 55.0, "customer_id": "C0121", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.918427	t
397	ORD5E3ACD64F9	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5E3ACD64F9", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-08-25T16:29:00", "unit_price": 260.0, "customer_id": "C0261", "customer_city": "Mumbai", "customer_name": "Sahil Iyer", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.920202	t
398	ORDEFF6491F57	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDEFF6491F57", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-09-27T08:52:00", "unit_price": 299.0, "customer_id": "C0126", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.921873	t
399	ORD8778EEEFD6	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD8778EEEFD6", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-10-01T13:55:00", "unit_price": 350.0, "customer_id": "C0028", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.923495	t
400	ORD5263E6549C	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD5263E6549C", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-08-31T20:59:00", "unit_price": 80.0, "customer_id": "C0238", "customer_city": "Pune", "customer_name": "Arjun Kulkarni", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.925028	t
401	ORD4F74A0BC49	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD4F74A0BC49", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-07-21T14:22:00", "unit_price": 40.0, "customer_id": "C0210", "customer_city": "Pune", "customer_name": "Sneha Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.926725	t
402	ORD68F057EFE2	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD68F057EFE2", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-01T22:30:00", "unit_price": 380.0, "customer_id": "C0400", "customer_city": "THANE", "customer_name": "  aarav kulkarni ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.928122	t
403	ORD2DD3E4A136	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD2DD3E4A136", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-30T19:01:00", "unit_price": 220.0, "customer_id": "C0132", "customer_city": "Mumbai", "customer_name": "Rohan Mehta", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.929707	t
404	ORDA52EE95E31	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA52EE95E31", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-07-30T21:43:00", "unit_price": 250.0, "customer_id": "C0347", "customer_city": "Thane", "customer_name": "Sahil Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.931219	t
405	ORD0DD778BCFC	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD0DD778BCFC", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-07-16T22:50:00", "unit_price": 40.0, "customer_id": "C0238", "customer_city": "Pune", "customer_name": "Arjun Kulkarni", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.932926	t
406	ORDD5353BFE5D	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDD5353BFE5D", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-08-31T09:13:00", "unit_price": 150.0, "customer_id": "C0003", "customer_city": "Pune", "customer_name": "Vikram Mehta", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.934511	t
407	ORDE869B31EDE	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDE869B31EDE", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-10-07T20:01:00", "unit_price": 80.0, "customer_id": "C0308", "customer_city": "PUNE", "customer_name": "  sahil kulkarni ", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.936131	t
408	ORDCAF5DB2AE0	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDCAF5DB2AE0", "quantity": 0, "item_name": "Garlic Bread", "order_time": "2026-08-08T22:50:00", "unit_price": 120.0, "customer_id": "C0268", "customer_city": "Mumbai", "customer_name": "Arjun Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.937757	t
409	ORD025DC2AD41	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD025DC2AD41", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-08-12T21:38:00", "unit_price": 280.0, "customer_id": "C0100", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.940012	t
410	ORD01B615163C	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD01B615163C", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-09-06T20:16:00", "unit_price": 40.0, "customer_id": "C0284", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.94168	t
411	ORD87B8E46F6B	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD87B8E46F6B", "quantity": 1, "item_name": "Raita", "order_time": "2026-07-27T14:08:00", "unit_price": 40.0, "customer_id": "C0209", "customer_city": "Pune", "customer_name": "Vikram Kulkarni", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:03.943485	t
412	ORD7FE63D3E65	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD7FE63D3E65", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-08-23T19:24:00", "unit_price": 190.0, "customer_id": "C0310", "customer_city": "Mumbai", "customer_name": "Riya Singh", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.945108	t
413	ORDC28B2523C7	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDC28B2523C7", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-09-27T14:53:00", "unit_price": 180.0, "customer_id": "C0009", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.946756	t
414	ORD3782F06FA8	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD3782F06FA8", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-08-05T22:26:00", "unit_price": 40.0, "customer_id": "C0160", "customer_city": "PUNE", "customer_name": "  kabir singh ", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.948397	t
415	ORDBFD9B18817	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDBFD9B18817", "quantity": 2, "item_name": "French Fries", "order_time": "2026-10-04T09:17:00", "unit_price": 90.0, "customer_id": "C0148", "customer_city": "Pune", "customer_name": "Aarav Mehta", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.949895	t
416	ORD7F8BDD4C99	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7F8BDD4C99", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-09-04T21:08:00", "unit_price": 220.0, "customer_id": "C0045", "customer_city": "Mumbai", "customer_name": "Vikram Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.951597	t
417	ORDF60DF5237D	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDF60DF5237D", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-09-24T19:59:00", "unit_price": 120.0, "customer_id": "C0018", "customer_city": "Mumbai", "customer_name": "Riya Sharma", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.953117	t
418	ORD43424A77AF	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD43424A77AF", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-08-30T13:01:00", "unit_price": 150.0, "customer_id": "C0113", "customer_city": "THANE", "customer_name": "  rohan sharma ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.955023	t
419	ORD7F7731464A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD7F7731464A", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-08-28T16:29:00", "unit_price": 350.0, "customer_id": "C0355", "customer_city": "Thane", "customer_name": "Sahil Joshi", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.956541	t
420	ORD4570924811	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD4570924811", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-07-30T20:11:00", "unit_price": 150.0, "customer_id": "C0118", "customer_city": "Pune", "customer_name": "Aarav Desai", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.958724	t
421	ORD72F353BA0E	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD72F353BA0E", "quantity": 1, "item_name": "French Fries", "order_time": "2026-07-15T20:46:00", "unit_price": 90.0, "customer_id": "C0273", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.960142	t
422	ORD5AA65BF58D	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5AA65BF58D", "quantity": 0, "item_name": "Chicken Wrap", "order_time": "2026-07-19T20:24:00", "unit_price": 140.0, "customer_id": "C0120", "customer_city": "Pune", "customer_name": "Vikram Singh", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.961753	t
423	ORD735CA20C4E	{"status": "PLACED", "cuisine": "Japanese", "order_id": "ORD735CA20C4E", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-03T13:44:00", "unit_price": 380.0, "customer_id": "C0178", "customer_city": "Thane", "customer_name": "Pooja Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.963318	t
424	ORD9BD44CC875	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD9BD44CC875", "quantity": 1, "item_name": "Manchurian", "order_time": "2026-07-20T13:34:00", "unit_price": 210.0, "customer_id": "C0211", "customer_city": "MUMBAI", "customer_name": "  sneha nair ", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.96536	t
425	ORDFC6D2D58E7	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDFC6D2D58E7", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-08-25T13:36:00", "unit_price": 150.0, "customer_id": "C0162", "customer_city": "Pune", "customer_name": "Priya Patil", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.967015	t
426	ORD51D2448B8C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD51D2448B8C", "quantity": 4, "item_name": "Butter Chicken", "order_time": "2026-09-16T19:00:00", "unit_price": 320.0, "customer_id": "C0245", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.968637	t
427	ORD2E62A1B395	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD2E62A1B395", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-09-30T13:47:00", "unit_price": 180.0, "customer_id": "C0275", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:03.971505	t
428	ORDF6960D972C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDF6960D972C", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-07-18T20:40:00", "unit_price": 280.0, "customer_id": "C0377", "customer_city": "Mumbai", "customer_name": "Neha Khan", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.978952	t
429	ORD3951F9511A	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD3951F9511A", "quantity": 1, "item_name": "French Fries", "order_time": "2026-08-01T14:16:00", "unit_price": 90.0, "customer_id": "C0273", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.979801	t
430	ORD2C2306D778	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD2C2306D778", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-09-26T19:34:00", "unit_price": 140.0, "customer_id": "C0335", "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.980627	t
431	ORDED13F67107	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDED13F67107", "quantity": 2, "item_name": "French Fries", "order_time": "2026-10-09T17:48:00", "unit_price": 90.0, "customer_id": "C0140", "customer_city": "Pune", "customer_name": "Priya Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:03.981458	t
432	ORD7D8FB5D2D0	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD7D8FB5D2D0", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-08-16T13:52:00", "unit_price": 110.0, "customer_id": "C0133", "customer_city": "Pune", "customer_name": "Vikram Mehta", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:03.98229	t
433	ORDF395696AA1	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDF395696AA1", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-08-05T13:03:00", "unit_price": 280.0, "customer_id": "C0187", "customer_city": "Mumbai", "customer_name": "Aarav Kulkarni", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.983634	t
434	ORDB992BA8026	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDB992BA8026", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-07-22T12:55:00", "unit_price": 60.0, "customer_id": "C0331", "customer_city": "Mumbai", "customer_name": "Rohan Mehta", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.984519	t
435	ORD3C349944B2	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3C349944B2", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-07-17T12:40:00", "unit_price": 350.0, "customer_id": "C0167", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.985375	t
436	ORDCBCDE0342D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCBCDE0342D", "quantity": 2, "item_name": "Garlic Naan", "order_time": "2026-09-04T22:27:00", "unit_price": 60.0, "customer_id": "C0152", "customer_city": "Mumbai", "customer_name": "Pooja Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.986863	t
437	ORDA56EF7B3BF	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDA56EF7B3BF", "quantity": 3, "item_name": "Pasta Alfredo", "order_time": "2026-07-15T13:02:00", "unit_price": 280.0, "customer_id": "C0232", "customer_city": "Mumbai", "customer_name": "Priya Iyer", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.987702	t
438	ORD585867F7B3	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD585867F7B3", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-08-16T17:45:00", "unit_price": 299.0, "customer_id": "C0123", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.988992	t
439	ORDBA2BB94712	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDBA2BB94712", "quantity": 0, "item_name": "Paneer Tikka", "order_time": "2026-07-21T22:26:00", "unit_price": 260.0, "customer_id": "C0106", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.989732	t
440	ORD4909117A2A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4909117A2A", "quantity": 2, "item_name": "Garlic Naan", "order_time": "2026-10-07T22:44:00", "unit_price": 60.0, "customer_id": "C0004", "customer_city": "Mumbai", "customer_name": "Aarav Iyer", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.99102	t
441	ORDA0CB2E6F90	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA0CB2E6F90", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-21T19:56:00", "unit_price": 340.0, "customer_id": "C0357", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.992355	t
442	ORD6E3801AF44	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6E3801AF44", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-09-03T17:07:00", "unit_price": 260.0, "customer_id": "C0156", "customer_city": "Mumbai", "customer_name": "Rohan Desai", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:03.993637	t
443	ORDAF367DAB19	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAF367DAB19", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-07-23T16:44:00", "unit_price": 350.0, "customer_id": "C0102", "customer_city": "Thane", "customer_name": "Anjali Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.994854	t
444	ORD7661D03D7C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD7661D03D7C", "quantity": 3, "item_name": "Pasta Alfredo", "order_time": "2026-10-04T22:45:00", "unit_price": 280.0, "customer_id": "C0065", "customer_city": "Mumbai", "customer_name": "Priya Mehta", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:03.996597	t
445	ORD20D6FC321E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD20D6FC321E", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-08-21T13:05:00", "unit_price": 250.0, "customer_id": "C0077", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:03.998049	t
446	ORD3FE9436E4F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3FE9436E4F", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-03T20:34:00", "unit_price": 350.0, "customer_id": "C0320", "customer_city": "Thane", "customer_name": "Priya Patil", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:03.999349	t
447	ORD10B8C2C300	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD10B8C2C300", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-10-10T20:44:00", "unit_price": 40.0, "customer_id": "C0353", "customer_city": "Pune", "customer_name": "Rohan Mehta", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.000906	t
448	ORDF5E611A0C2	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDF5E611A0C2", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-08-28T12:40:00", "unit_price": 110.0, "customer_id": "C0038", "customer_city": "Pune", "customer_name": "Anjali Patil", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.002344	t
449	ORD1EC48A584D	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD1EC48A584D", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-07-18T12:36:00", "unit_price": 40.0, "customer_id": "C0388", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.0042	t
450	ORD892F9180F9	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD892F9180F9", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-10-09T21:30:00", "unit_price": 40.0, "customer_id": "C0134", "customer_city": "Pune", "customer_name": "Aarav Patil", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.005717	t
451	ORDE19AF2A93D	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDE19AF2A93D", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-09-06T21:40:00", "unit_price": 110.0, "customer_id": "C0038", "customer_city": "Pune", "customer_name": "Anjali Patil", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.007223	t
452	ORDF6CE0A4B6C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDF6CE0A4B6C", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-11T16:17:00", "unit_price": 280.0, "customer_id": "C0114", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.008803	t
453	ORD621125EE3F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD621125EE3F", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-07-22T12:00:00", "unit_price": 110.0, "customer_id": "C0263", "customer_city": "Pune", "customer_name": "Riya Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.01054	t
454	ORDE49E05B743	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE49E05B743", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-30T17:19:00", "unit_price": 280.0, "customer_id": "C0070", "customer_city": "Mumbai", "customer_name": "Vikram Mehta", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.012182	t
455	ORD1ADAF38AC2	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD1ADAF38AC2", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-08-07T09:00:00", "unit_price": 260.0, "customer_id": "C0105", "customer_city": "Mumbai", "customer_name": "Neha Nair", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.013993	t
456	ORDE8FCAA7863	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDE8FCAA7863", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-07-15T13:45:00", "unit_price": 280.0, "customer_id": "C0193", "customer_city": "Pune", "customer_name": "Riya Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.0156	t
457	ORDA50087A40F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA50087A40F", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-08-03T17:25:00", "unit_price": 150.0, "customer_id": "C0300", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.01725	t
458	ORDECDC2EA923	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDECDC2EA923", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-07-24T21:56:00", "unit_price": 150.0, "customer_id": "C0121", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.018573	t
459	ORD37E7BFDA6F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD37E7BFDA6F", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-16T20:58:00", "unit_price": 150.0, "customer_id": "C0184", "customer_city": "Pune", "customer_name": "Sahil Kulkarni", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.020172	t
460	ORD736C3E70F5	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD736C3E70F5", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-09-24T20:59:00", "unit_price": 120.0, "customer_id": "C0288", "customer_city": "MUMBAI", "customer_name": "  kabir iyer ", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.021858	t
461	ORDB48E5BEC7D	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDB48E5BEC7D", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-09-27T22:14:00", "unit_price": 80.0, "customer_id": "C0248", "customer_city": "Pune", "customer_name": "Rohan Mehta", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.023386	t
462	ORDB7CA06000A	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDB7CA06000A", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-25T12:59:00", "unit_price": 250.0, "customer_id": "C0283", "customer_city": "Thane", "customer_name": "Sahil Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.024721	t
463	ORDCF3C72DA23	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDCF3C72DA23", "quantity": 4, "item_name": "Raita", "order_time": "2026-07-18T21:01:00", "unit_price": 40.0, "customer_id": "C0054", "customer_city": "Pune", "customer_name": "Vikram Desai", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.026003	t
464	ORD3996DE1DFE	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD3996DE1DFE", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-10-07T13:43:00", "unit_price": 299.0, "customer_id": "C0211", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.027589	t
465	ORDCA6C6A6F04	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCA6C6A6F04", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-09-25T09:55:00", "unit_price": 220.0, "customer_id": "C0310", "customer_city": "Mumbai", "customer_name": "Riya Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.029083	t
466	ORD97ADB0E462	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORD97ADB0E462", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-07-17T16:06:00", "unit_price": 380.0, "customer_id": "C0056", "customer_city": "Thane", "customer_name": "Sneha Singh", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.03072	t
467	ORD5EFB4F65FD	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5EFB4F65FD", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-07-29T14:47:00", "unit_price": 150.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Pooja Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.03232	t
468	ORD851E0281FF	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD851E0281FF", "quantity": 3, "item_name": "French Fries", "order_time": "2026-08-18T08:57:00", "unit_price": 90.0, "customer_id": "C0076", "customer_city": "Pune", "customer_name": "Rohan Khan", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.033803	t
469	ORD91A1EB126C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD91A1EB126C", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-08-30T16:47:00", "unit_price": 55.0, "customer_id": null, "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.035383	t
470	ORD340CE38C7D	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD340CE38C7D", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-09-07T12:39:00", "unit_price": 150.0, "customer_id": "C0378", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.036956	t
471	ORDF02E1B07A8	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF02E1B07A8", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-19T17:11:00", "unit_price": 340.0, "customer_id": "C0090", "customer_city": "Thane", "customer_name": "Arjun Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.038564	t
472	ORD6C28FE1EC6	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6C28FE1EC6", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-26T21:18:00", "unit_price": 340.0, "customer_id": "C0356", "customer_city": "Thane", "customer_name": "Arjun Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.039776	t
473	ORD5B29574403	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD5B29574403", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-25T20:05:00", "unit_price": 350.0, "customer_id": "C0384", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.041128	t
474	ORD09BCBAEB1B	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORD09BCBAEB1B", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-09-30T20:43:00", "unit_price": 180.0, "customer_id": "C0380", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.042822	t
475	ORDC506F07596	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDC506F07596", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-09-08T13:24:00", "unit_price": 120.0, "customer_id": "C0022", "customer_city": "Mumbai", "customer_name": "Arjun Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.044223	t
476	ORD03CB00DBBF	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD03CB00DBBF", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-10-08T21:30:00", "unit_price": 150.0, "customer_id": "C0259", "customer_city": "Pune", "customer_name": "Riya Joshi", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.045729	t
477	ORD6C981C6130	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD6C981C6130", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-08-03T13:49:00", "unit_price": 150.0, "customer_id": "C0139", "customer_city": "Thane", "customer_name": "Priya Iyer", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.047197	t
478	ORDE88B161BFE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE88B161BFE", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-10-06T20:37:00", "unit_price": 250.0, "customer_id": "C0028", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.048934	t
479	ORDA927D95768	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA927D95768", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-08-21T16:34:00", "unit_price": 350.0, "customer_id": "C0046", "customer_city": "Thane", "customer_name": "Anjali Iyer", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.050418	t
480	ORD4FFA77E5F5	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD4FFA77E5F5", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-07-17T21:07:00", "unit_price": 190.0, "customer_id": "C0332", "customer_city": "Mumbai", "customer_name": "Rohan Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.051888	t
481	ORD9D66256430	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9D66256430", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-07-14T14:16:00", "unit_price": 380.0, "customer_id": "C0035", "customer_city": "Thane", "customer_name": "Priya Sharma", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.053648	t
482	ORD07AB09D9F4	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD07AB09D9F4", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-07-16T20:54:00", "unit_price": 220.0, "customer_id": "C0291", "customer_city": "Pune", "customer_name": "Sneha Desai", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.055497	t
483	ORD703E2E65C4	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD703E2E65C4", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-07T16:40:00", "unit_price": 280.0, "customer_id": "C0349", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.056879	t
484	ORDE8727232A0	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE8727232A0", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-10-02T21:40:00", "unit_price": 180.0, "customer_id": "C0161", "customer_city": "Mumbai", "customer_name": "Rohan Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.05825	t
485	ORD2D9FE088FC	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD2D9FE088FC", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-08-26T20:23:00", "unit_price": 320.0, "customer_id": "C0147", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.059691	t
486	ORD8B0DDF1E72	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD8B0DDF1E72", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-07-21T08:26:00", "unit_price": 350.0, "customer_id": "C0319", "customer_city": "Thane", "customer_name": "Sahil Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.061417	t
487	ORD3BD38034C4	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD3BD38034C4", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-08-15T21:40:00", "unit_price": -120.0, "customer_id": "C0354", "customer_city": "Mumbai", "customer_name": "Arjun Sharma", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.062959	t
488	ORDE8AB1F0F66	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE8AB1F0F66", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-09-11T21:05:00", "unit_price": 120.0, "customer_id": "C0037", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.064453	t
489	ORD107181C18D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD107181C18D", "quantity": 1, "item_name": "Paneer Tikka", "order_time": "2026-09-29T21:16:00", "unit_price": 260.0, "customer_id": "C0380", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.066212	t
490	ORD8608D91AF5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8608D91AF5", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-08-09T17:47:00", "unit_price": 220.0, "customer_id": "C0354", "customer_city": "Mumbai", "customer_name": "Arjun Sharma", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.067739	t
491	ORDB562E65217	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB562E65217", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-08-07T20:28:00", "unit_price": 210.0, "customer_id": "C0095", "customer_city": "Mumbai", "customer_name": "Pooja Sharma", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.069212	t
492	ORDBC788FCECD	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDBC788FCECD", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-08-21T13:59:00", "unit_price": 350.0, "customer_id": "C0072", "customer_city": "THANE", "customer_name": "  sneha sharma ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.070943	t
493	ORD7B0692FD03	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7B0692FD03", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-07-13T16:51:00", "unit_price": 220.0, "customer_id": "C0005", "customer_city": "Mumbai", "customer_name": "Rohan Kulkarni", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.072649	t
494	ORDB609F6D42C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB609F6D42C", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-08-22T20:30:00", "unit_price": 210.0, "customer_id": "C0371", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.074313	t
495	ORD25D13F641F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD25D13F641F", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-10-09T08:21:00", "unit_price": 140.0, "customer_id": "C0367", "customer_city": "Pune", "customer_name": "Neha Nair", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.07582	t
496	ORD9F3B950BAF	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD9F3B950BAF", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-10-02T13:46:00", "unit_price": 150.0, "customer_id": "C0356", "customer_city": "Thane", "customer_name": "Arjun Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.077243	t
497	ORD601DB1EEF0	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD601DB1EEF0", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-08-17T14:16:00", "unit_price": 190.0, "customer_id": "C0268", "customer_city": "Mumbai", "customer_name": "Arjun Patil", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.078921	t
498	ORDCD2167AE7F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCD2167AE7F", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-08-28T21:26:00", "unit_price": 260.0, "customer_id": "C0375", "customer_city": "Mumbai", "customer_name": "Vikram Patil", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.08044	t
499	ORD1575C31E18	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD1575C31E18", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-08-21T14:48:00", "unit_price": 80.0, "customer_id": "C0075", "customer_city": "Pune", "customer_name": "Pooja Joshi", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.081887	t
500	ORDAC846AFF93	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAC846AFF93", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-08-14T16:25:00", "unit_price": 350.0, "customer_id": "C0247", "customer_city": "THANE", "customer_name": "  kabir khan ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.083453	t
501	ORDA2AF9DC806	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDA2AF9DC806", "quantity": 2, "item_name": "Chicken Biryani", "order_time": "2026-09-09T20:31:00", "unit_price": 280.0, "customer_id": "C0253", "customer_city": "Pune", "customer_name": "Neha Nair", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.08503	t
502	ORD041D082AB9	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD041D082AB9", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-09-22T14:55:00", "unit_price": 220.0, "customer_id": "C0058", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.086866	t
503	ORDBB9AB0B5D9	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORDBB9AB0B5D9", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-20T13:11:00", "unit_price": 180.0, "customer_id": "C0336", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.088957	t
504	ORDF9CE1840CC	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF9CE1840CC", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-08-14T08:25:00", "unit_price": 260.0, "customer_id": "C0280", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.090559	t
505	ORD1B8683D721	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD1B8683D721", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-07-20T09:11:00", "unit_price": 340.0, "customer_id": "C0137", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.092217	t
506	ORDE68FBECE63	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE68FBECE63", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-08-14T13:16:00", "unit_price": 280.0, "customer_id": "C0368", "customer_city": "Mumbai", "customer_name": "Riya Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.093857	t
507	ORD89A01251C4	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD89A01251C4", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-07-22T13:51:00", "unit_price": 120.0, "customer_id": "C0114", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.095761	t
508	ORDA0099545C5	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDA0099545C5", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-26T20:05:00", "unit_price": 120.0, "customer_id": "C0044", "customer_city": "MUMBAI", "customer_name": "  rohan patil ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.097283	t
509	ORDA8ACF171AE	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDA8ACF171AE", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-10-01T22:58:00", "unit_price": 299.0, "customer_id": "C0206", "customer_city": "Mumbai", "customer_name": "Riya Joshi", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.098808	t
510	ORD1AE837A178	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD1AE837A178", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-08-21T09:13:00", "unit_price": 140.0, "customer_id": "C0052", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.100639	t
511	ORDC4481C632C	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC4481C632C", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-08-11T08:44:00", "unit_price": 140.0, "customer_id": "C0291", "customer_city": "Pune", "customer_name": "Sneha Desai", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.102526	t
512	ORD6EE8BF2882	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD6EE8BF2882", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-02T12:39:00", "unit_price": 120.0, "customer_id": "C0084", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.105317	t
513	ORDC923553C4E	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC923553C4E", "quantity": 3, "item_name": "French Fries", "order_time": "2026-07-20T20:09:00", "unit_price": 90.0, "customer_id": "C0052", "customer_city": "PUNE", "customer_name": "  kabir iyer ", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.108181	t
514	ORDFDA454D206	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORDFDA454D206", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-08-29T22:13:00", "unit_price": 380.0, "customer_id": "C0205", "customer_city": "Thane", "customer_name": "Sneha Kulkarni", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.110458	t
515	ORD8513E5FB82	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8513E5FB82", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-10-02T21:26:00", "unit_price": 340.0, "customer_id": "C0341", "customer_city": "Thane", "customer_name": "Vikram Mehta", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.112041	t
516	ORDF835851080	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDF835851080", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-07-14T08:17:00", "unit_price": 299.0, "customer_id": "C0175", "customer_city": "MUMBAI", "customer_name": "  sahil khan ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.113755	t
517	ORDFE0DB09CD7	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDFE0DB09CD7", "quantity": 3, "item_name": "Masala Dosa", "order_time": "2026-08-15T09:39:00", "unit_price": 110.0, "customer_id": "C0291", "customer_city": "Pune", "customer_name": "Sneha Desai", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.115428	t
518	ORD0361168A08	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0361168A08", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-09-02T08:07:00", "unit_price": 320.0, "customer_id": "C0207", "customer_city": "Mumbai", "customer_name": "Kabir Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.117465	t
519	ORDD2FBCEA5FD	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDD2FBCEA5FD", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-22T19:12:00", "unit_price": 180.0, "customer_id": "C0062", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.118927	t
520	ORD0AD12D4F98	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0AD12D4F98", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-09-01T16:08:00", "unit_price": 250.0, "customer_id": "C0400", "customer_city": "Thane", "customer_name": "Aarav Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.122181	t
521	ORD48098247A1	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD48098247A1", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-07-23T16:44:00", "unit_price": 280.0, "customer_id": "C0396", "customer_city": "Pune", "customer_name": "Kabir Desai", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.125746	t
522	ORD0667499D94	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD0667499D94", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-10-04T21:13:00", "unit_price": 80.0, "customer_id": "C0221", "customer_city": "Pune", "customer_name": "Kabir Kulkarni", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.127894	t
523	ORD17E30491ED	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD17E30491ED", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-01T16:30:00", "unit_price": 380.0, "customer_id": "C0364", "customer_city": "Thane", "customer_name": "Sahil Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.1296	t
524	ORDE660C7AFD9	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE660C7AFD9", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-23T13:23:00", "unit_price": 120.0, "customer_id": "C0179", "customer_city": "Mumbai", "customer_name": "Vikram Singh", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.131065	t
525	ORD7B7B09FF82	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD7B7B09FF82", "quantity": 4, "item_name": "Pasta Alfredo", "order_time": "2026-09-04T19:28:00", "unit_price": 280.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.132779	t
526	ORD9308D08B4E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9308D08B4E", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-07-31T21:51:00", "unit_price": 60.0, "customer_id": "C0079", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.134672	t
527	ORD7AFE762E85	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD7AFE762E85", "quantity": 3, "item_name": "French Fries", "order_time": "2026-07-17T17:53:00", "unit_price": 90.0, "customer_id": "C0248", "customer_city": "Pune", "customer_name": "Rohan Mehta", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.136227	t
528	ORDFC3F67EE20	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDFC3F67EE20", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-08-11T20:57:00", "unit_price": 55.0, "customer_id": "C0315", "customer_city": "Thane", "customer_name": "Vikram Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.137852	t
529	ORD93B426AF0C	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD93B426AF0C", "quantity": 2, "item_name": "Chicken Biryani", "order_time": "2026-10-05T13:34:00", "unit_price": 280.0, "customer_id": "C0348", "customer_city": "Pune", "customer_name": "Anjali Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.139658	t
530	ORD32A3AEE740	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD32A3AEE740", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-07-16T09:15:00", "unit_price": 340.0, "customer_id": "C0314", "customer_city": "Thane", "customer_name": "Arjun Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.141015	t
531	ORD393836E290	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD393836E290", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-05T14:06:00", "unit_price": 340.0, "customer_id": "C0145", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.142487	t
532	ORDAF39006971	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAF39006971", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-07-28T09:19:00", "unit_price": 380.0, "customer_id": "C0113", "customer_city": "Thane", "customer_name": "Rohan Sharma", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.144141	t
533	ORD34585BA2E7	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD34585BA2E7", "quantity": 3, "item_name": "Chicken Biryani", "order_time": "2026-08-20T09:14:00", "unit_price": 280.0, "customer_id": "C0233", "customer_city": "Pune", "customer_name": "Riya Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.145857	t
534	ORDB32B5CC7CD	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDB32B5CC7CD", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-08-05T20:20:00", "unit_price": 150.0, "customer_id": "C0341", "customer_city": "THANE", "customer_name": "  vikram mehta ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.147167	t
535	ORD87DC13A547	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD87DC13A547", "quantity": 2, "item_name": "Chicken Biryani", "order_time": "2026-09-12T19:43:00", "unit_price": 280.0, "customer_id": "C0209", "customer_city": "PUNE", "customer_name": "  vikram kulkarni ", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.148775	t
536	ORD022B0C1014	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD022B0C1014", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-08-05T09:31:00", "unit_price": 299.0, "customer_id": "C0144", "customer_city": "Mumbai", "customer_name": "Aarav Iyer", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.15041	t
537	ORDBB9E7D830B	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDBB9E7D830B", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-10-01T14:08:00", "unit_price": 210.0, "customer_id": "C0079", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.152052	t
538	ORD8F62A1E4DB	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8F62A1E4DB", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-13T19:08:00", "unit_price": 340.0, "customer_id": "C0387", "customer_city": "Thane", "customer_name": "Riya Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.153475	t
539	ORDA42CC5AC99	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA42CC5AC99", "quantity": 3, "item_name": "Masala Dosa", "order_time": "2026-07-31T09:36:00", "unit_price": 110.0, "customer_id": "C0208", "customer_city": "Pune", "customer_name": "Sahil Desai", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.154905	t
540	ORDE6343827B4	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE6343827B4", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-08-31T13:55:00", "unit_price": 150.0, "customer_id": "C0101", "customer_city": "Thane", "customer_name": "Kabir Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.156447	t
541	ORDF3017206C3	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDF3017206C3", "quantity": 2, "item_name": "French Fries", "order_time": "2026-09-18T13:58:00", "unit_price": 90.0, "customer_id": "C0251", "customer_city": "PUNE", "customer_name": "  arjun patil ", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.158119	t
542	ORD978CA40844	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD978CA40844", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-10-07T19:48:00", "unit_price": 120.0, "customer_id": "C0062", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.159595	t
543	ORD16980F6651	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD16980F6651", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-08-06T20:10:00", "unit_price": 80.0, "customer_id": "C0217", "customer_city": "Pune", "customer_name": "Anjali Kulkarni", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.161104	t
544	ORDB19D067622	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB19D067622", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-09-16T20:05:00", "unit_price": 55.0, "customer_id": "C0031", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.162479	t
545	ORD80D307047E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD80D307047E", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-28T14:26:00", "unit_price": 250.0, "customer_id": "C0247", "customer_city": "Thane", "customer_name": "Kabir Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.164145	t
546	ORD0C154C9ADF	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD0C154C9ADF", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-27T20:39:00", "unit_price": 120.0, "customer_id": "C0022", "customer_city": "Mumbai", "customer_name": "Arjun Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.165704	t
547	ORD92C70F9644	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD92C70F9644", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-08-09T20:35:00", "unit_price": 180.0, "customer_id": "C0305", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.167	t
548	ORD614118B407	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD614118B407", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-09-10T13:55:00", "unit_price": 250.0, "customer_id": "C0370", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.16855	t
549	ORD54A4C5E0D6	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD54A4C5E0D6", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-07-29T13:55:00", "unit_price": 299.0, "customer_id": "C0282", "customer_city": "Mumbai", "customer_name": "Neha Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.170256	t
550	ORD49C1B9A291	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD49C1B9A291", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-09-24T14:57:00", "unit_price": 340.0, "customer_id": "C0112", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.171772	t
551	ORD9762A16916	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9762A16916", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-09-21T09:03:00", "unit_price": 320.0, "customer_id": "C0196", "customer_city": "MUMBAI", "customer_name": "  neha singh ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.173332	t
552	ORD070B3D4D48	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD070B3D4D48", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-10-06T13:03:00", "unit_price": 250.0, "customer_id": "C0370", "customer_city": "THANE", "customer_name": "  sahil khan ", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.175002	t
553	ORDACEB654619	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDACEB654619", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-10-02T21:52:00", "unit_price": 350.0, "customer_id": "C0023", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.176563	t
554	ORD3888CA18D3	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3888CA18D3", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-09-22T16:26:00", "unit_price": 150.0, "customer_id": "C0362", "customer_city": "Thane", "customer_name": "Anjali Nair", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.177967	t
555	ORD1F5EAF9C3E	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1F5EAF9C3E", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-08-26T19:30:00", "unit_price": 210.0, "customer_id": "C0279", "customer_city": "Mumbai", "customer_name": "Rohan Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.179465	t
556	ORD3A3F553EE7	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3A3F553EE7", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-08-19T21:32:00", "unit_price": 250.0, "customer_id": "C0274", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.181226	t
557	ORD70DB12F854	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD70DB12F854", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-10-05T19:03:00", "unit_price": 220.0, "customer_id": "C0284", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.183055	t
558	ORD276703C980	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD276703C980", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-10-04T09:08:00", "unit_price": 190.0, "customer_id": "C0129", "customer_city": "Mumbai", "customer_name": "Riya Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.184462	t
559	ORD17BC54ECEB	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD17BC54ECEB", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-07-14T21:20:00", "unit_price": 140.0, "customer_id": "C0259", "customer_city": "PUNE", "customer_name": "  riya joshi ", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.185717	t
560	ORDB0499341BA	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDB0499341BA", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-08-14T13:01:00", "unit_price": 40.0, "customer_id": "C0294", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.187471	t
561	ORD28A51B5934	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORD28A51B5934", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-08-20T17:49:00", "unit_price": 210.0, "customer_id": "C0372", "customer_city": "Mumbai", "customer_name": "Priya Kulkarni", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.188882	t
562	ORD020EB11630	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD020EB11630", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-17T13:21:00", "unit_price": 280.0, "customer_id": "C0372", "customer_city": "Mumbai", "customer_name": "Priya Kulkarni", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.190379	t
563	ORD216363F08A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD216363F08A", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-07-24T08:35:00", "unit_price": 340.0, "customer_id": "C0351", "customer_city": "THANE", "customer_name": "  priya desai ", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.191774	t
564	ORD1AF30C7D6B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD1AF30C7D6B", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-01T14:19:00", "unit_price": 340.0, "customer_id": "C0068", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.193441	t
565	ORDEE5480B944	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORDEE5480B944", "quantity": 4, "item_name": "French Fries", "order_time": "2026-08-20T22:39:00", "unit_price": 90.0, "customer_id": "C0186", "customer_city": "Pune", "customer_name": "Neha Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.194804	t
566	ORDCA527E9631	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORDCA527E9631", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-08-16T13:36:00", "unit_price": 180.0, "customer_id": "C0045", "customer_city": "Mumbai", "customer_name": "Vikram Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.196259	t
567	ORDCF96205BBB	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCF96205BBB", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-09T21:26:00", "unit_price": 220.0, "customer_id": "C0082", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.197776	t
568	ORDBD674B9714	{"status": "PLACED", "cuisine": "Fast Food", "order_id": "ORDBD674B9714", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-07-31T22:32:00", "unit_price": 150.0, "customer_id": "C0200", "customer_city": "Pune", "customer_name": "Pooja Mehta", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.199267	t
569	ORDB7ECF54603	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB7ECF54603", "quantity": 4, "item_name": "Raita", "order_time": "2026-08-14T09:28:00", "unit_price": 40.0, "customer_id": "C0027", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.200916	t
570	ORDF726EEEC7B	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDF726EEEC7B", "quantity": 4, "item_name": "Veg Biryani", "order_time": "2026-09-23T20:59:00", "unit_price": 220.0, "customer_id": "C0091", "customer_city": "Pune", "customer_name": "Sahil Patil", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.202357	t
571	ORD628448FA21	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD628448FA21", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-18T19:36:00", "unit_price": 380.0, "customer_id": "C0365", "customer_city": "Thane", "customer_name": "Sneha Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.204146	t
572	ORD442177DE3F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD442177DE3F", "quantity": 1, "item_name": "Paneer Tikka", "order_time": "2026-08-29T12:04:00", "unit_price": 260.0, "customer_id": "C0022", "customer_city": "Mumbai", "customer_name": "Arjun Khan", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.205434	t
573	ORDB12B465BFD	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB12B465BFD", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-09-25T13:14:00", "unit_price": 210.0, "customer_id": "C0258", "customer_city": "Mumbai", "customer_name": "Neha Desai", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.206943	t
574	ORDF42C0EDA66	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORDF42C0EDA66", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-10-03T12:01:00", "unit_price": 220.0, "customer_id": "C0076", "customer_city": "Pune", "customer_name": "Rohan Khan", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.208609	t
575	ORDABBDFDFB17	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDABBDFDFB17", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-08-27T17:46:00", "unit_price": 220.0, "customer_id": "C0381", "customer_city": "Pune", "customer_name": "Sahil Patil", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.210193	t
576	ORD043ACBAD67	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD043ACBAD67", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-09-23T19:54:00", "unit_price": 280.0, "customer_id": "C0393", "customer_city": "Pune", "customer_name": "Riya Mehta", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.211644	t
577	ORD91EF08507E	{"status": "PLACED", "cuisine": "Fast Food", "order_id": "ORD91EF08507E", "quantity": 3, "item_name": "French Fries", "order_time": "2026-09-15T21:33:00", "unit_price": 90.0, "customer_id": "C0030", "customer_city": "PUNE", "customer_name": "  riya patil ", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.213137	t
578	ORD0B3C1B4A29	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0B3C1B4A29", "quantity": 4, "item_name": "Butter Chicken", "order_time": "2026-08-06T21:11:00", "unit_price": 320.0, "customer_id": "C0282", "customer_city": "Mumbai", "customer_name": "Neha Khan", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.214727	t
579	ORDFFAA60AEE6	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDFFAA60AEE6", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-09-21T20:59:00", "unit_price": 180.0, "customer_id": "C0344", "customer_city": "Mumbai", "customer_name": "Kabir Patil", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.216205	t
580	ORD0291384546	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD0291384546", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-09-12T22:20:00", "unit_price": 150.0, "customer_id": "C0249", "customer_city": "Pune", "customer_name": "Kabir Khan", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.217992	t
581	ORDA13A496B3B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA13A496B3B", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-08-11T17:23:00", "unit_price": 150.0, "customer_id": "C0124", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.21927	t
582	ORDCDB0A3FDB3	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDCDB0A3FDB3", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-07T21:23:00", "unit_price": 180.0, "customer_id": "C0195", "customer_city": "Mumbai", "customer_name": "Sahil Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.220848	t
583	ORDE6B14A6F5F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE6B14A6F5F", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-01T21:12:00", "unit_price": 150.0, "customer_id": "C0378", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.222246	t
584	ORD8944EDFA13	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8944EDFA13", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-08-12T20:36:00", "unit_price": 60.0, "customer_id": "C0226", "customer_city": "Mumbai", "customer_name": "Sahil Iyer", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.223844	t
585	ORD86682717DA	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD86682717DA", "quantity": 1, "item_name": "Raita", "order_time": "2026-08-02T08:24:00", "unit_price": 40.0, "customer_id": "C0231", "customer_city": "Pune", "customer_name": "Anjali Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.225425	t
586	ORD413220369A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD413220369A", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-07-13T14:23:00", "unit_price": 55.0, "customer_id": "C0012", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.226983	t
587	ORDFB58B99186	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDFB58B99186", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-08-30T20:24:00", "unit_price": 120.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Rohan Mehta", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.228512	t
588	ORD75DBCD6946	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD75DBCD6946", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-10-03T16:16:00", "unit_price": 150.0, "customer_id": "C0064", "customer_city": "Pune", "customer_name": "Anjali Mehta", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.230082	t
589	ORD0B24DD224F	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD0B24DD224F", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-08-28T14:41:00", "unit_price": 220.0, "customer_id": "C0186", "customer_city": "Pune", "customer_name": "Neha Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-10 15:26:04.231874	t
590	ORD4A80C3B24C	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD4A80C3B24C", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-09-18T20:06:00", "unit_price": 150.0, "customer_id": "C0399", "customer_city": "Pune", "customer_name": "Sneha Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.23341	t
591	ORDFF127EBC68	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDFF127EBC68", "quantity": 2, "item_name": "French Fries", "order_time": "2026-09-28T21:56:00", "unit_price": 90.0, "customer_id": "C0100", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.234711	t
592	ORD41C3CE7058	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD41C3CE7058", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-02T12:41:00", "unit_price": 350.0, "customer_id": "C0333", "customer_city": "Thane", "customer_name": "Sahil Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.236316	t
593	ORD276AFCD8AE	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD276AFCD8AE", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-07-16T19:47:00", "unit_price": 40.0, "customer_id": "C0291", "customer_city": "Pune", "customer_name": "Sneha Desai", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.238147	t
594	ORD2743CDB04D	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2743CDB04D", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-09-28T20:41:00", "unit_price": 380.0, "customer_id": "C0384", "customer_city": "THANE", "customer_name": "  rohan kulkarni ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.239568	t
595	ORDE02CEEA879	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE02CEEA879", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-08-11T21:55:00", "unit_price": 60.0, "customer_id": "C0265", "customer_city": "Mumbai", "customer_name": "Riya Nair", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-10 15:26:04.241167	t
596	ORD9DE6C1B98E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9DE6C1B98E", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-10-09T22:17:00", "unit_price": 340.0, "customer_id": "C0271", "customer_city": "THANE", "customer_name": "  aarav mehta ", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-10 15:26:04.242756	t
597	ORD5FEB5F32B4	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD5FEB5F32B4", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-08-28T14:23:00", "unit_price": 150.0, "customer_id": "C0160", "customer_city": "Pune", "customer_name": "Kabir Singh", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-10 15:26:04.244408	t
598	ORD07274AFCCD	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD07274AFCCD", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-28T14:07:00", "unit_price": 350.0, "customer_id": "C0110", "customer_city": "Thane", "customer_name": "Kabir Desai", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-10 15:26:04.246061	t
599	ORD02BB0610A6	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD02BB0610A6", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-07-23T20:24:00", "unit_price": 40.0, "customer_id": "C0389", "customer_city": "Pune", "customer_name": "Arjun Mehta", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.247379	t
600	ORD7448FAB15A	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD7448FAB15A", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-08-16T12:20:00", "unit_price": 210.0, "customer_id": "C0014", "customer_city": "Mumbai", "customer_name": "Arjun Khan", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-10 15:26:04.249216	t
601	ORDFB1CD9D8C7	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDFB1CD9D8C7", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-10-04T08:26:00", "unit_price": 80.0, "customer_id": "C0016", "customer_city": "Pune", "customer_name": "Pooja Patil", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.250549	t
602	ORD9CA83824E0	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD9CA83824E0", "quantity": 0, "item_name": "Masala Dosa", "order_time": "2026-09-10T19:24:00", "unit_price": 110.0, "customer_id": "C0215", "customer_city": "Pune", "customer_name": "Sahil Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-10 15:26:04.252045	t
603	ORD3928EEEC10	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD3928EEEC10", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-07-21T09:32:00", "unit_price": 299.0, "customer_id": "C0067", "customer_city": "Mumbai", "customer_name": "Aarav Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-10 15:26:04.253586	t
607	ORD881A6B03A7	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD881A6B03A7", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-08-26T21:21:00", "unit_price": 299.0, "customer_id": "C0209", "customer_city": "Mumbai", "customer_name": "Priya Iyer", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.342773	t
608	ORDAE6ECA9B01	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDAE6ECA9B01", "quantity": 3, "item_name": "Pasta Alfredo", "order_time": "2026-09-17T13:16:00", "unit_price": 280.0, "customer_id": "C0279", "customer_city": "Mumbai", "customer_name": "Aarav Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.343669	t
609	ORDA4187BC319	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDA4187BC319", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-09-07T09:03:00", "unit_price": 140.0, "customer_id": "C0397", "customer_city": "Pune", "customer_name": "Pooja Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.344564	t
610	ORDE44EC9E001	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE44EC9E001", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-07-29T17:31:00", "unit_price": 210.0, "customer_id": "C0365", "customer_city": "Mumbai", "customer_name": "Rohan Singh", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.345446	t
611	ORD24E0E492B7	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD24E0E492B7", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-10-01T09:00:00", "unit_price": 55.0, "customer_id": "C0341", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.346267	t
612	ORD748CA8F4F0	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD748CA8F4F0", "quantity": 0, "item_name": "Filter Coffee", "order_time": "2026-08-31T22:29:00", "unit_price": 40.0, "customer_id": "C0217", "customer_city": "Pune", "customer_name": "Pooja Nair", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.347073	t
613	ORD75550C417B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD75550C417B", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-09-08T22:17:00", "unit_price": 150.0, "customer_id": "C0121", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.347963	t
614	ORD282F267214	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD282F267214", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-09-25T13:39:00", "unit_price": 150.0, "customer_id": "C0308", "customer_city": "Pune", "customer_name": "Pooja Joshi", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.348807	t
615	ORD39F7721C31	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD39F7721C31", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-08-29T13:30:00", "unit_price": 250.0, "customer_id": "C0333", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.349686	t
616	ORDF8DBD6640B	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDF8DBD6640B", "quantity": 1, "item_name": "French Fries", "order_time": "2026-08-21T13:05:00", "unit_price": 90.0, "customer_id": "C0200", "customer_city": "Pune", "customer_name": "Riya Iyer", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.3513	t
617	ORDF3FA3AE223	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORDF3FA3AE223", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-10-02T20:29:00", "unit_price": 150.0, "customer_id": "C0041", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.352734	t
618	ORD77BAD207FE	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD77BAD207FE", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-10-10T21:14:00", "unit_price": 380.0, "customer_id": "C0079", "customer_city": "Thane", "customer_name": "Aarav Patil", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.353677	t
619	ORD9125134CD8	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD9125134CD8", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-18T17:18:00", "unit_price": 120.0, "customer_id": "C0104", "customer_city": "Mumbai", "customer_name": "Vikram Iyer", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.354676	t
620	ORD25D3C6C39B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD25D3C6C39B", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-30T09:58:00", "unit_price": 380.0, "customer_id": "C0321", "customer_city": "THANE", "customer_name": "  pooja nair ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.355575	t
621	ORDBAF692366C	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDBAF692366C", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-07-27T16:31:00", "unit_price": 299.0, "customer_id": "C0311", "customer_city": "Mumbai", "customer_name": "Arjun Mehta", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.356459	t
622	ORD023C4F2CE5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD023C4F2CE5", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-08-08T19:01:00", "unit_price": 220.0, "customer_id": "C0365", "customer_city": "Mumbai", "customer_name": "Rohan Singh", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.357291	t
623	ORDADF5C31054	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDADF5C31054", "quantity": 3, "item_name": "French Fries", "order_time": "2026-08-18T16:52:00", "unit_price": 90.0, "customer_id": "C0359", "customer_city": "PUNE", "customer_name": "  priya kulkarni ", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.358138	t
624	ORD47162E6EDD	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD47162E6EDD", "quantity": 2, "item_name": "Butter Chicken", "order_time": "2026-10-06T16:20:00", "unit_price": 320.0, "customer_id": "C0311", "customer_city": "Mumbai", "customer_name": "Arjun Mehta", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.359046	t
625	ORD1042BA7473	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD1042BA7473", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-08-22T22:30:00", "unit_price": 350.0, "customer_id": "C0161", "customer_city": "Thane", "customer_name": "Sneha Patil", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.359891	t
626	ORDDDDB4E9A05	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDDDDB4E9A05", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-18T19:23:00", "unit_price": 250.0, "customer_id": "C0095", "customer_city": "Thane", "customer_name": "Riya Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.360641	t
627	ORDB8989D1491	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDB8989D1491", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-08-10T13:06:00", "unit_price": 350.0, "customer_id": "C0352", "customer_city": "Thane", "customer_name": "Riya Mehta", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.361331	t
628	ORD1F68092B3C	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD1F68092B3C", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-10-07T20:38:00", "unit_price": 140.0, "customer_id": "C0138", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.36206	t
629	ORD3751AC38AB	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD3751AC38AB", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-09-20T19:52:00", "unit_price": 280.0, "customer_id": "C0309", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.362806	t
630	ORD8995188888	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD8995188888", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-09-04T21:57:00", "unit_price": 190.0, "customer_id": "C0252", "customer_city": "Mumbai", "customer_name": "Kabir Sharma", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.363496	t
631	ORD4E316F5780	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4E316F5780", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-27T19:52:00", "unit_price": 220.0, "customer_id": "C0188", "customer_city": "Mumbai", "customer_name": "Riya Iyer", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.364215	t
632	ORD4FC11CAA73	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD4FC11CAA73", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-26T21:18:00", "unit_price": 380.0, "customer_id": "C0127", "customer_city": "THANE", "customer_name": "  neha iyer ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.364947	t
633	ORD2E8E335192	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD2E8E335192", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-10-05T20:39:00", "unit_price": 55.0, "customer_id": "C0212", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.365647	t
634	ORD32A8CBE316	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD32A8CBE316", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-10-01T08:18:00", "unit_price": 340.0, "customer_id": "C0097", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.366476	t
635	ORD888590397A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD888590397A", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-08-09T13:23:00", "unit_price": 260.0, "customer_id": "C0322", "customer_city": "Mumbai", "customer_name": "Rohan Patil", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.36712	t
636	ORDC2ACE9C3D8	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDC2ACE9C3D8", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-08-09T20:31:00", "unit_price": 180.0, "customer_id": "C0313", "customer_city": "MUMBAI", "customer_name": "  pooja joshi ", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.367833	t
637	ORD9FB04E2CEA	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD9FB04E2CEA", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-09-22T22:59:00", "unit_price": 140.0, "customer_id": "C0144", "customer_city": "PUNE", "customer_name": "  neha sharma ", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.368536	t
638	ORDDE6BA9C976	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDDE6BA9C976", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-14T20:03:00", "unit_price": 280.0, "customer_id": "C0152", "customer_city": "MUMBAI", "customer_name": "  anjali sharma ", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.369199	t
639	ORDCA9A9CE46F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCA9A9CE46F", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-09-08T17:53:00", "unit_price": 340.0, "customer_id": "C0201", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.369809	t
640	ORD760BB50B10	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD760BB50B10", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-15T20:41:00", "unit_price": 150.0, "customer_id": "C0084", "customer_city": "THANE", "customer_name": "  riya singh ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.370456	t
641	ORD2329882884	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2329882884", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-08-08T09:08:00", "unit_price": 150.0, "customer_id": "C0278", "customer_city": "Thane", "customer_name": "Sahil Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.371096	t
642	ORD11CB70F543	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD11CB70F543", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-31T13:51:00", "unit_price": 250.0, "customer_id": "C0231", "customer_city": "Thane", "customer_name": "Aarav Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.371761	t
643	ORDE52A710878	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE52A710878", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-10-08T13:27:00", "unit_price": 190.0, "customer_id": "C0353", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.37244	t
644	ORDCD203859B3	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDCD203859B3", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-09-30T21:36:00", "unit_price": 299.0, "customer_id": "C0293", "customer_city": "Mumbai", "customer_name": "Anjali Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.37306	t
645	ORD4D0303EBE1	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD4D0303EBE1", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-09-28T20:52:00", "unit_price": 40.0, "customer_id": "C0072", "customer_city": "Pune", "customer_name": "Arjun Desai", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.373692	t
646	ORD31CE0C859D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD31CE0C859D", "quantity": 3, "item_name": "Butter Chicken", "order_time": "2026-07-31T13:59:00", "unit_price": 320.0, "customer_id": "C0011", "customer_city": "Mumbai", "customer_name": "Anjali Kulkarni", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.374248	t
647	ORD9D429497EF	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9D429497EF", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-09-30T12:05:00", "unit_price": 55.0, "customer_id": "C0263", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.374783	t
648	ORDDEEB72445B	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDDEEB72445B", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-10-09T13:11:00", "unit_price": 220.0, "customer_id": "C0002", "customer_city": "Pune", "customer_name": "Rohan Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.375407	t
649	ORDE0C574E0C7	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE0C574E0C7", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-08-02T08:41:00", "unit_price": 350.0, "customer_id": "C0176", "customer_city": "Thane", "customer_name": "Kabir Kulkarni", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.375995	t
650	ORD11F0B1FB15	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD11F0B1FB15", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-09-10T22:04:00", "unit_price": 299.0, "customer_id": "C0353", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.376604	t
651	ORD27561CA5CB	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD27561CA5CB", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-18T08:15:00", "unit_price": 380.0, "customer_id": "C0292", "customer_city": "Thane", "customer_name": "Pooja Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.377178	t
652	ORD000494B802	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD000494B802", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-09-18T20:48:00", "unit_price": 250.0, "customer_id": "C0161", "customer_city": "Thane", "customer_name": "Sneha Patil", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.377738	t
653	ORD8A1C7FD41C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8A1C7FD41C", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-03T21:02:00", "unit_price": 340.0, "customer_id": "C0338", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.378327	t
654	ORD118C50DE71	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD118C50DE71", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-19T09:27:00", "unit_price": 180.0, "customer_id": "C0225", "customer_city": "Mumbai", "customer_name": "Priya Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.378944	t
655	ORD15AEC2327F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD15AEC2327F", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-09-14T14:47:00", "unit_price": 55.0, "customer_id": "C0273", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.379517	t
656	ORD61E1B92559	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD61E1B92559", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-07-23T13:44:00", "unit_price": 140.0, "customer_id": "C0238", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.380081	t
657	ORD774EEAD29C	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD774EEAD29C", "quantity": 2, "item_name": "French Fries", "order_time": "2026-07-29T12:46:00", "unit_price": 90.0, "customer_id": "C0387", "customer_city": "Pune", "customer_name": "Priya Joshi", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.380616	t
658	ORD0616204282	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD0616204282", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-08-31T20:54:00", "unit_price": -150.0, "customer_id": "C0175", "customer_city": "Pune", "customer_name": "Kabir Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.381144	t
659	ORD3BC532BA91	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3BC532BA91", "quantity": 2, "item_name": "Garlic Naan", "order_time": "2026-10-05T14:45:00", "unit_price": 60.0, "customer_id": "C0293", "customer_city": "Mumbai", "customer_name": "Anjali Patil", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.381662	t
660	ORDD4D3C86D22	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDD4D3C86D22", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-08-28T08:00:00", "unit_price": 350.0, "customer_id": "C0265", "customer_city": "Thane", "customer_name": "Vikram Sharma", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.382173	t
661	ORD05502D7827	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD05502D7827", "quantity": 1, "item_name": "Masala Dosa", "order_time": "2026-08-02T22:31:00", "unit_price": 110.0, "customer_id": "C0136", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.38272	t
662	ORD2697AD499B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2697AD499B", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-07-17T13:32:00", "unit_price": 350.0, "customer_id": "C0263", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.38345	t
663	ORDA8A91FF6A3	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDA8A91FF6A3", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-07-29T20:44:00", "unit_price": 140.0, "customer_id": "C0075", "customer_city": "Pune", "customer_name": "Neha Joshi", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.383977	t
664	ORD54A5D60D82	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD54A5D60D82", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-07-19T08:18:00", "unit_price": 250.0, "customer_id": "C0042", "customer_city": "Thane", "customer_name": "Rohan Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.38452	t
665	ORD266EC038D3	{"status": "PLACED", "cuisine": "Italian", "order_id": "ORD266EC038D3", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-27T13:55:00", "unit_price": 120.0, "customer_id": "C0271", "customer_city": "Mumbai", "customer_name": "Kabir Nair", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.385064	t
666	ORD0B200ACDFD	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0B200ACDFD", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-07-17T22:14:00", "unit_price": 340.0, "customer_id": "C0314", "customer_city": "Thane", "customer_name": "Priya Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.38561	t
667	ORD0637F2F3FE	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD0637F2F3FE", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-27T19:22:00", "unit_price": 380.0, "customer_id": "C0036", "customer_city": "Thane", "customer_name": "Priya Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.386119	t
668	ORD1CE7FD768B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD1CE7FD768B", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-09-21T13:44:00", "unit_price": 260.0, "customer_id": "C0065", "customer_city": "Mumbai", "customer_name": "Vikram Joshi", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.38666	t
669	ORD6DE113DB05	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD6DE113DB05", "quantity": 1, "item_name": "Manchurian", "order_time": "2026-09-09T19:53:00", "unit_price": 210.0, "customer_id": "C0104", "customer_city": "Mumbai", "customer_name": "Vikram Iyer", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.387172	t
670	ORDE89ED4026E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE89ED4026E", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-07-24T12:03:00", "unit_price": 340.0, "customer_id": "C0067", "customer_city": "THANE", "customer_name": "  anjali patil ", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.387684	t
671	ORD8EA8032EF1	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD8EA8032EF1", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-09-02T17:59:00", "unit_price": 150.0, "customer_id": "C0302", "customer_city": "Pune", "customer_name": "Rohan Nair", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.388207	t
672	ORD7F8D58074C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD7F8D58074C", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-01T14:00:00", "unit_price": 150.0, "customer_id": "C0291", "customer_city": "Thane", "customer_name": "Kabir Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.38872	t
673	ORD2934B6A03F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD2934B6A03F", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-07-22T21:17:00", "unit_price": 150.0, "customer_id": "C0359", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.389238	t
674	ORDCE7944E9A7	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDCE7944E9A7", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-09-17T21:24:00", "unit_price": 190.0, "customer_id": "C0288", "customer_city": "Mumbai", "customer_name": "Anjali Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.389762	t
675	ORDE13C91D207	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE13C91D207", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-07-25T17:49:00", "unit_price": 210.0, "customer_id": "C0323", "customer_city": "Mumbai", "customer_name": "Priya Kulkarni", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.390346	t
676	ORD0B8A2899E8	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD0B8A2899E8", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-29T20:15:00", "unit_price": 220.0, "customer_id": "C0140", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.391021	t
677	ORD26C9088D95	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD26C9088D95", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-07-30T22:18:00", "unit_price": 280.0, "customer_id": "C0379", "customer_city": "PUNE", "customer_name": "  priya singh ", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.391619	t
678	ORDAAEB26083C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAAEB26083C", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-09-12T09:18:00", "unit_price": 55.0, "customer_id": "C0257", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.392194	t
679	ORDE286DE88C7	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDE286DE88C7", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-08-05T20:15:00", "unit_price": 220.0, "customer_id": "C0091", "customer_city": "Pune", "customer_name": "Neha Sharma", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.392733	t
680	ORD7B08488A68	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORD7B08488A68", "quantity": 3, "item_name": "Raita", "order_time": "2026-09-23T20:57:00", "unit_price": 40.0, "customer_id": "C0105", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.393303	t
681	ORD4802B214D1	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4802B214D1", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-08-22T14:20:00", "unit_price": 55.0, "customer_id": "C0095", "customer_city": "Thane", "customer_name": "Riya Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.393855	t
682	ORDE52A710878	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE52A710878", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-10-08T13:27:00", "unit_price": 190.0, "customer_id": "C0353", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.394332	t
683	ORDE51E22A86B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE51E22A86B", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-08-06T09:03:00", "unit_price": 340.0, "customer_id": "C0354", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.394821	t
684	ORD70071CEC49	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD70071CEC49", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-09-23T12:57:00", "unit_price": 350.0, "customer_id": "C0166", "customer_city": "Thane", "customer_name": "Neha Patil", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.395278	t
685	ORDC05AD2E89B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC05AD2E89B", "quantity": 4, "item_name": "Paneer Tikka", "order_time": "2026-09-29T21:39:00", "unit_price": 260.0, "customer_id": "C0353", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.395752	t
686	ORD79E3BDF0BA	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD79E3BDF0BA", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-08-25T21:05:00", "unit_price": 250.0, "customer_id": "C0366", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.396221	t
687	ORDE285F534A7	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE285F534A7", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-19T13:34:00", "unit_price": 380.0, "customer_id": "C0160", "customer_city": "Thane", "customer_name": "Aarav Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.396707	t
688	ORD4012D5E3A9	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD4012D5E3A9", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-08-26T14:50:00", "unit_price": 180.0, "customer_id": "C0156", "customer_city": "Mumbai", "customer_name": "Vikram Mehta", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.397177	t
689	ORD8796FF375C	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD8796FF375C", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-24T17:25:00", "unit_price": 150.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.397651	t
690	ORD702BE33FE0	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD702BE33FE0", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-08-29T22:53:00", "unit_price": 150.0, "customer_id": "C0173", "customer_city": "Thane", "customer_name": "Anjali Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.398125	t
691	ORD628330857A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD628330857A", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-07-19T20:02:00", "unit_price": 60.0, "customer_id": "C0140", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.398771	t
692	ORDB3EE41647F	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDB3EE41647F", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-09-01T09:12:00", "unit_price": 120.0, "customer_id": "C0301", "customer_city": "Mumbai", "customer_name": "Anjali Sharma", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.399227	t
693	ORD4EC7D7937D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4EC7D7937D", "quantity": 1, "item_name": "Paneer Tikka", "order_time": "2026-07-25T21:20:00", "unit_price": 260.0, "customer_id": "C0031", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.399676	t
694	ORDAADD370A3A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAADD370A3A", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-10-02T12:11:00", "unit_price": 380.0, "customer_id": "C0137", "customer_city": "THANE", "customer_name": "  neha iyer ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.400119	t
695	ORD2F57409912	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD2F57409912", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-10-01T09:44:00", "unit_price": 299.0, "customer_id": "C0113", "customer_city": "Mumbai", "customer_name": "Anjali Singh", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.400567	t
696	ORD5F9C9D7DB4	{"status": "PLACED", "cuisine": "Chinese", "order_id": "ORD5F9C9D7DB4", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-10-02T16:10:00", "unit_price": 180.0, "customer_id": "C0322", "customer_city": "MUMBAI", "customer_name": "  rohan patil ", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.401016	t
697	ORD7CF7D7994F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7CF7D7994F", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-08-24T22:26:00", "unit_price": 250.0, "customer_id": "C0201", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.401497	t
698	ORD9C85D91A20	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9C85D91A20", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-09-21T09:06:00", "unit_price": 55.0, "customer_id": "C0171", "customer_city": "Thane", "customer_name": "Sneha Singh", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.401967	t
699	ORD479A01C78C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD479A01C78C", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-09-28T09:08:00", "unit_price": 180.0, "customer_id": "C0360", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.402474	t
700	ORD63803CE529	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD63803CE529", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-07-29T14:41:00", "unit_price": 150.0, "customer_id": "C0056", "customer_city": "Pune", "customer_name": "Vikram Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.402916	t
701	ORD9E1B048CF1	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD9E1B048CF1", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-07-30T16:00:00", "unit_price": 220.0, "customer_id": "C0002", "customer_city": "Pune", "customer_name": "Rohan Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.403326	t
702	ORDA2C397E6C5	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDA2C397E6C5", "quantity": 2, "item_name": "Raita", "order_time": "2026-09-05T21:53:00", "unit_price": 40.0, "customer_id": "C0300", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.403724	t
703	ORDB737447EE5	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB737447EE5", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-08-27T08:31:00", "unit_price": 220.0, "customer_id": "C0105", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.404119	t
704	ORD0A04AC8DF0	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORD0A04AC8DF0", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-08-25T08:12:00", "unit_price": 280.0, "customer_id": "C0041", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.404554	t
705	ORD2F2A22633F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD2F2A22633F", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-09-04T19:21:00", "unit_price": 140.0, "customer_id": "C0241", "customer_city": "Pune", "customer_name": "Sneha Mehta", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.404943	t
706	ORDA1019E9F7D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA1019E9F7D", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-09-08T09:54:00", "unit_price": 260.0, "customer_id": "C0236", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.405345	t
707	ORD46A94248C1	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD46A94248C1", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-15T22:29:00", "unit_price": -280.0, "customer_id": "C0274", "customer_city": "Mumbai", "customer_name": "Aarav Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.405773	t
708	ORD967D50F53B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD967D50F53B", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-08-30T19:03:00", "unit_price": 340.0, "customer_id": "C0061", "customer_city": "Thane", "customer_name": "Anjali Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.406193	t
709	ORD5420C3416D	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD5420C3416D", "quantity": 0, "item_name": "Manchurian", "order_time": "2026-09-07T22:07:00", "unit_price": 210.0, "customer_id": "C0224", "customer_city": "Mumbai", "customer_name": "Neha Joshi", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.406581	t
710	ORD593499D5BF	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD593499D5BF", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-28T20:11:00", "unit_price": 150.0, "customer_id": "C0196", "customer_city": "Thane", "customer_name": "Vikram Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.406987	t
711	ORDB0EF09D9C4	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDB0EF09D9C4", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-07-31T13:19:00", "unit_price": 350.0, "customer_id": "C0118", "customer_city": "Thane", "customer_name": "Riya Patil", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.407384	t
712	ORD10C7E39072	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD10C7E39072", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-09-11T12:48:00", "unit_price": 299.0, "customer_id": "C0335", "customer_city": "Mumbai", "customer_name": "Kabir Nair", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.407808	t
713	ORD0ED3606321	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD0ED3606321", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-07-22T16:12:00", "unit_price": 350.0, "customer_id": "C0222", "customer_city": "Thane", "customer_name": "Vikram Sharma", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.408219	t
714	ORD43A85C4100	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD43A85C4100", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-09-15T20:19:00", "unit_price": 180.0, "customer_id": "C0152", "customer_city": "Mumbai", "customer_name": "Anjali Sharma", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.408654	t
715	ORD169C4AEE7F	{"status": "CANCELLED", "cuisine": "Chinese", "order_id": "ORD169C4AEE7F", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-10-04T16:08:00", "unit_price": 210.0, "customer_id": "C0240", "customer_city": "Mumbai", "customer_name": "Anjali Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.40906	t
716	ORD7900F9FD5B	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD7900F9FD5B", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-08-23T21:59:00", "unit_price": 40.0, "customer_id": "C0269", "customer_city": "Pune", "customer_name": "Pooja Khan", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.409464	t
717	ORD59D25CE156	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD59D25CE156", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-09-22T19:47:00", "unit_price": 250.0, "customer_id": "C0079", "customer_city": "Thane", "customer_name": "Aarav Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.409865	t
718	ORDABF11F07FF	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDABF11F07FF", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-09-20T14:49:00", "unit_price": 190.0, "customer_id": "C0271", "customer_city": "Mumbai", "customer_name": "Kabir Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.410251	t
719	ORD8F2A985A55	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8F2A985A55", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-08-27T19:00:00", "unit_price": 55.0, "customer_id": "C0169", "customer_city": "Thane", "customer_name": "Rohan Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.410634	t
720	ORD0E02341376	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0E02341376", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-08-07T22:26:00", "unit_price": 250.0, "customer_id": "C0057", "customer_city": "Thane", "customer_name": "Vikram Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.411161	t
721	ORDE544BD7273	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE544BD7273", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-09-21T13:23:00", "unit_price": 350.0, "customer_id": "C0030", "customer_city": "Thane", "customer_name": "Sneha Iyer", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.411524	t
722	ORDAA9C98CBA7	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDAA9C98CBA7", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-08-25T13:33:00", "unit_price": 150.0, "customer_id": "C0297", "customer_city": "Pune", "customer_name": "Sneha Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.411891	t
723	ORD566AB6AF11	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD566AB6AF11", "quantity": 1, "item_name": "Paneer Tikka", "order_time": "2026-10-03T16:27:00", "unit_price": 260.0, "customer_id": "C0255", "customer_city": "Mumbai", "customer_name": "Arjun Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.412245	t
724	ORDAE0642DE46	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAE0642DE46", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-08-02T22:02:00", "unit_price": 350.0, "customer_id": "C0094", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.412612	t
725	ORDEAAC79FD4B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEAAC79FD4B", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-30T08:32:00", "unit_price": 340.0, "customer_id": "C0160", "customer_city": "Thane", "customer_name": "Aarav Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.412976	t
726	ORD1A165BBD67	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD1A165BBD67", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-10-01T22:17:00", "unit_price": 280.0, "customer_id": "C0047", "customer_city": "Mumbai", "customer_name": "Vikram Nair", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.413333	t
727	ORD200DB44E45	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD200DB44E45", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-08-03T20:49:00", "unit_price": 340.0, "customer_id": "C0228", "customer_city": "Thane", "customer_name": "Neha Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.413702	t
728	ORDD22BEE193D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD22BEE193D", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-10-14T17:36:00", "unit_price": 340.0, "customer_id": "C0196", "customer_city": "Thane", "customer_name": "Vikram Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.414075	t
729	ORD888FFB219A	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD888FFB219A", "quantity": 1, "item_name": "French Fries", "order_time": "2026-10-11T14:17:00", "unit_price": 90.0, "customer_id": "C0285", "customer_city": "Pune", "customer_name": "Anjali Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.414462	t
730	ORD8A0A6C7B34	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD8A0A6C7B34", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-09-20T13:55:00", "unit_price": 350.0, "customer_id": "C0074", "customer_city": "Thane", "customer_name": "Priya Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.415043	t
731	ORD47CB3BBFCA	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD47CB3BBFCA", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-08-28T17:07:00", "unit_price": 180.0, "customer_id": "C0360", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.415447	t
732	ORDC3E651DF57	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC3E651DF57", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-07-24T09:52:00", "unit_price": 140.0, "customer_id": "C0144", "customer_city": "Pune", "customer_name": "Neha Sharma", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.415842	t
733	ORD68961102B6	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD68961102B6", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-22T22:05:00", "unit_price": 150.0, "customer_id": "C0176", "customer_city": "Thane", "customer_name": "Kabir Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.416211	t
734	ORD23F661658E	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD23F661658E", "quantity": 3, "item_name": "Chicken Biryani", "order_time": "2026-08-02T22:20:00", "unit_price": 280.0, "customer_id": "C0367", "customer_city": "Pune", "customer_name": "Riya Desai", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.416602	t
735	ORD50809FA513	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD50809FA513", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-10T20:17:00", "unit_price": 340.0, "customer_id": "C0171", "customer_city": "Thane", "customer_name": "Sneha Singh", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.416971	t
736	ORD1C92076922	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD1C92076922", "quantity": 3, "item_name": "Chicken Biryani", "order_time": "2026-09-18T13:33:00", "unit_price": 280.0, "customer_id": "C0376", "customer_city": "Pune", "customer_name": "Arjun Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.417409	t
737	ORD1EC29694EE	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD1EC29694EE", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-08-01T20:54:00", "unit_price": 150.0, "customer_id": "C0320", "customer_city": "Pune", "customer_name": "Priya Desai", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.418125	t
738	ORDCBD5016570	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCBD5016570", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-08-04T14:24:00", "unit_price": 60.0, "customer_id": "C0242", "customer_city": "Mumbai", "customer_name": "Priya Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.41853	t
739	ORD8D669A2C3F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8D669A2C3F", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-07T20:38:00", "unit_price": 55.0, "customer_id": "C0336", "customer_city": "Thane", "customer_name": "Riya Iyer", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.418969	t
740	ORDFEA940738B	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORDFEA940738B", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-09-14T19:39:00", "unit_price": 80.0, "customer_id": "C0397", "customer_city": "Pune", "customer_name": "Pooja Iyer", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.419401	t
741	ORD57CF8C2871	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD57CF8C2871", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-07-23T12:15:00", "unit_price": 350.0, "customer_id": "C0344", "customer_city": "Thane", "customer_name": "Rohan Patil", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.419846	t
742	ORD8DF3C912F7	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD8DF3C912F7", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-07-29T13:56:00", "unit_price": 299.0, "customer_id": "C0280", "customer_city": "Mumbai", "customer_name": "Sahil Joshi", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.420246	t
743	ORD8AE6DE7D65	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD8AE6DE7D65", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-10-04T20:20:00", "unit_price": 80.0, "customer_id": "C0393", "customer_city": "Pune", "customer_name": "Priya Joshi", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.420659	t
744	ORDE928A137B5	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE928A137B5", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-09-02T21:47:00", "unit_price": 180.0, "customer_id": "C0301", "customer_city": "Mumbai", "customer_name": "Anjali Sharma", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.421051	t
745	ORDE80AC6D76A	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDE80AC6D76A", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-07-24T16:03:00", "unit_price": 220.0, "customer_id": "C0012", "customer_city": "Pune", "customer_name": "Riya Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.421427	t
746	ORD60FFF8D2AA	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD60FFF8D2AA", "quantity": 1, "item_name": "French Fries", "order_time": "2026-08-30T21:10:00", "unit_price": 90.0, "customer_id": "C0032", "customer_city": "Pune", "customer_name": "Kabir Khan", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.421805	t
747	ORDB12DA5795A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB12DA5795A", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-08-17T14:36:00", "unit_price": 60.0, "customer_id": "C0340", "customer_city": "Mumbai", "customer_name": "Sahil Sharma", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.422161	t
748	ORDEA959832DD	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEA959832DD", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-09-12T19:37:00", "unit_price": 55.0, "customer_id": "C0042", "customer_city": "Thane", "customer_name": "Rohan Desai", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.422554	t
749	ORD7D41EFE079	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD7D41EFE079", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-09-20T16:23:00", "unit_price": 140.0, "customer_id": "C0385", "customer_city": "Pune", "customer_name": "Vikram Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.42317	t
750	ORDD33C368DF9	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD33C368DF9", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-10-04T12:30:00", "unit_price": 260.0, "customer_id": "C0323", "customer_city": "Mumbai", "customer_name": "Priya Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.423655	t
751	ORD7AB329E7D6	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD7AB329E7D6", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-07-18T09:39:00", "unit_price": 350.0, "customer_id": "C0079", "customer_city": "Thane", "customer_name": "Aarav Patil", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.424113	t
752	ORD71CA719821	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD71CA719821", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-10-13T21:47:00", "unit_price": 250.0, "customer_id": "C0291", "customer_city": "Thane", "customer_name": "Kabir Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.424528	t
753	ORD3297E57B91	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD3297E57B91", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-08-01T21:58:00", "unit_price": 40.0, "customer_id": "C0106", "customer_city": "Pune", "customer_name": "Riya Joshi", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.424936	t
754	ORD37FF392EFC	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD37FF392EFC", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-10-12T19:59:00", "unit_price": 150.0, "customer_id": "C0155", "customer_city": "Pune", "customer_name": "Rohan Mehta", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.425429	t
755	ORDD10B600B3B	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORDD10B600B3B", "quantity": 0, "item_name": "Masala Dosa", "order_time": "2026-07-20T12:14:00", "unit_price": 110.0, "customer_id": "C0002", "customer_city": "Pune", "customer_name": "Rohan Singh", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.425876	t
756	ORD09EAF75DCF	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD09EAF75DCF", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-07-28T14:44:00", "unit_price": 340.0, "customer_id": "C0096", "customer_city": "Thane", "customer_name": "Sneha Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.42633	t
757	ORD9B9CC9F4B9	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9B9CC9F4B9", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-09-23T22:43:00", "unit_price": 55.0, "customer_id": "C0115", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.426786	t
758	ORD76B1603D75	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD76B1603D75", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-09-08T09:02:00", "unit_price": 40.0, "customer_id": "C0010", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.427241	t
759	ORDEE2A22C87D	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEE2A22C87D", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-07-31T13:56:00", "unit_price": 250.0, "customer_id": "C0115", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.427641	t
760	ORDC2219B2F51	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDC2219B2F51", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-08-25T09:47:00", "unit_price": 150.0, "customer_id": "C0046", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.428045	t
761	ORD65183A9E19	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD65183A9E19", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-07-17T12:57:00", "unit_price": 55.0, "customer_id": "C0263", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.428471	t
762	ORD6DC292D199	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD6DC292D199", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-09-15T16:17:00", "unit_price": 220.0, "customer_id": "C0221", "customer_city": "Pune", "customer_name": "Arjun Nair", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.428866	t
763	ORD3E75242D57	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3E75242D57", "quantity": 2, "item_name": "Garlic Naan", "order_time": "2026-09-30T13:13:00", "unit_price": 60.0, "customer_id": "C0279", "customer_city": "Mumbai", "customer_name": "Aarav Singh", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.429254	t
764	ORD5AE5953511	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD5AE5953511", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-08T22:26:00", "unit_price": 280.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Riya Singh", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.429595	t
765	ORD298385F823	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD298385F823", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-08-16T19:20:00", "unit_price": 220.0, "customer_id": "C0310", "customer_city": "Mumbai", "customer_name": "Anjali Kulkarni", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.429974	t
766	ORDB4CA4B2803	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB4CA4B2803", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-09-22T08:35:00", "unit_price": 220.0, "customer_id": "C0308", "customer_city": "PUNE", "customer_name": "  pooja joshi ", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.430323	t
767	ORD7C8574CDEF	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7C8574CDEF", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-27T17:27:00", "unit_price": 55.0, "customer_id": "C0372", "customer_city": "Thane", "customer_name": "Neha Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.430662	t
768	ORDE137D0FD6D	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORDE137D0FD6D", "quantity": 1, "item_name": "Cheese Burger", "order_time": "2026-09-17T20:36:00", "unit_price": 150.0, "customer_id": "C0181", "customer_city": "Pune", "customer_name": "Rohan Sharma", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.431086	t
769	ORDBD3C7CFE01	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDBD3C7CFE01", "quantity": 3, "item_name": "Manchurian", "order_time": "2026-07-26T17:41:00", "unit_price": 210.0, "customer_id": null, "customer_city": "Mumbai", "customer_name": "Priya Iyer", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.431534	t
770	ORDF1472C14DC	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDF1472C14DC", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-21T20:14:00", "unit_price": 120.0, "customer_id": "C0236", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.432126	t
771	ORDEAD39F19A1	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDEAD39F19A1", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-30T09:41:00", "unit_price": 55.0, "customer_id": "C0182", "customer_city": "Thane", "customer_name": "Sneha Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.432514	t
772	ORDA2625B9D71	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA2625B9D71", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-10-08T21:56:00", "unit_price": 350.0, "customer_id": "C0159", "customer_city": "Thane", "customer_name": "Sneha Sharma", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.432913	t
773	ORD6F22B375B3	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD6F22B375B3", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-10-14T12:18:00", "unit_price": 280.0, "customer_id": "C0224", "customer_city": "Mumbai", "customer_name": "Neha Joshi", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.433429	t
774	ORD6354E5EDFC	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD6354E5EDFC", "quantity": 1, "item_name": "Manchurian", "order_time": "2026-09-05T19:37:00", "unit_price": 210.0, "customer_id": "C0022", "customer_city": "Mumbai", "customer_name": "Priya Nair", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.43383	t
775	ORD3A0FC4044B	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD3A0FC4044B", "quantity": 2, "item_name": "French Fries", "order_time": "2026-08-06T13:16:00", "unit_price": 90.0, "customer_id": "C0219", "customer_city": "PUNE", "customer_name": "  arjun nair ", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.434176	t
776	ORD053CEE6B66	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD053CEE6B66", "quantity": 1, "item_name": "French Fries", "order_time": "2026-08-22T12:19:00", "unit_price": 90.0, "customer_id": "C0122", "customer_city": "Pune", "customer_name": "Anjali Sharma", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.434523	t
777	ORDF348227393	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF348227393", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-20T21:11:00", "unit_price": 150.0, "customer_id": "C0114", "customer_city": "Thane", "customer_name": "Kabir Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.434874	t
778	ORD44FC80D16F	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD44FC80D16F", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-08-31T17:20:00", "unit_price": 120.0, "customer_id": "C0210", "customer_city": "Mumbai", "customer_name": "Anjali Joshi", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.435363	t
779	ORD7514B0A1E8	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD7514B0A1E8", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-09-12T16:22:00", "unit_price": 120.0, "customer_id": "C0233", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.435692	t
780	ORD5223372F7C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD5223372F7C", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-09-10T09:09:00", "unit_price": 180.0, "customer_id": "C0192", "customer_city": "Mumbai", "customer_name": "Aarav Patil", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.436028	t
781	ORD415659DFA2	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD415659DFA2", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-09-18T19:02:00", "unit_price": 250.0, "customer_id": "C0218", "customer_city": "Thane", "customer_name": "Neha Patil", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.436346	t
782	ORDA3645A15AE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA3645A15AE", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-10-07T21:50:00", "unit_price": 250.0, "customer_id": "C0007", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.436687	t
783	ORDC14722E1F9	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDC14722E1F9", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-10-08T09:55:00", "unit_price": 340.0, "customer_id": "C0169", "customer_city": "Thane", "customer_name": "Rohan Patil", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.437023	t
784	ORD00B6F20F2B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD00B6F20F2B", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-08-12T13:47:00", "unit_price": 250.0, "customer_id": "C0128", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.437351	t
785	ORD52210C9FC2	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD52210C9FC2", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-08-10T22:53:00", "unit_price": 250.0, "customer_id": "C0141", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.437684	t
786	ORD16153FD51F	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD16153FD51F", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-09-03T17:46:00", "unit_price": 180.0, "customer_id": "C0210", "customer_city": "Mumbai", "customer_name": "Anjali Joshi", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.438003	t
787	ORDD1AA5126F6	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORDD1AA5126F6", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-10-06T17:18:00", "unit_price": 55.0, "customer_id": "C0190", "customer_city": "Thane", "customer_name": "Rohan Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.438329	t
788	ORD1A7050DA52	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD1A7050DA52", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-09-18T20:54:00", "unit_price": 150.0, "customer_id": "C0003", "customer_city": "Thane", "customer_name": "Neha Mehta", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.438642	t
789	ORD1CE7FD768B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD1CE7FD768B", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-09-21T13:44:00", "unit_price": 260.0, "customer_id": "C0065", "customer_city": "Mumbai", "customer_name": "Vikram Joshi", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.438958	t
790	ORDD09867B857	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDD09867B857", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-09-26T20:53:00", "unit_price": 150.0, "customer_id": "C0295", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.439275	t
791	ORD064C4A583B	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD064C4A583B", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-09-05T21:13:00", "unit_price": -210.0, "customer_id": "C0204", "customer_city": "Mumbai", "customer_name": "Arjun Mehta", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.439623	t
792	ORDCE4FC087BC	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDCE4FC087BC", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-29T14:18:00", "unit_price": 220.0, "customer_id": "C0300", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.439962	t
793	ORD784026497F	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORD784026497F", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-09-21T14:49:00", "unit_price": 110.0, "customer_id": "C0133", "customer_city": "Pune", "customer_name": "Sneha Patil", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.440297	t
794	ORDDBD07E5B36	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDDBD07E5B36", "quantity": 4, "item_name": "Veg Biryani", "order_time": "2026-09-09T13:06:00", "unit_price": 220.0, "customer_id": "C0105", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.440629	t
795	ORD59872C37AD	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD59872C37AD", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-07-21T21:19:00", "unit_price": 40.0, "customer_id": "C0008", "customer_city": "Pune", "customer_name": "Neha Iyer", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.440955	t
796	ORDD1A09E6D87	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD1A09E6D87", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-07-30T21:25:00", "unit_price": 250.0, "customer_id": "C0062", "customer_city": "Thane", "customer_name": "Anjali Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.441283	t
797	ORD15273CE64F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD15273CE64F", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-10-10T13:18:00", "unit_price": 150.0, "customer_id": "C0366", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.441611	t
798	ORDD341D44D7B	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDD341D44D7B", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-10-13T20:52:00", "unit_price": 280.0, "customer_id": "C0229", "customer_city": "Mumbai", "customer_name": "Arjun Iyer", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.44195	t
799	ORDD7568F054C	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDD7568F054C", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-08-05T20:19:00", "unit_price": 260.0, "customer_id": "C0134", "customer_city": "Mumbai", "customer_name": "Sneha Khan", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.442284	t
800	ORD7AABA0B687	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD7AABA0B687", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-09-14T20:26:00", "unit_price": 140.0, "customer_id": "C0037", "customer_city": "Pune", "customer_name": "Anjali Iyer", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.442609	t
801	ORDA54BDA7358	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDA54BDA7358", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-10-07T09:24:00", "unit_price": 180.0, "customer_id": "C0274", "customer_city": "Mumbai", "customer_name": "Aarav Singh", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.442942	t
802	ORD2010A342B7	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD2010A342B7", "quantity": 1, "item_name": "Masala Dosa", "order_time": "2026-10-07T21:39:00", "unit_price": 110.0, "customer_id": "C0318", "customer_city": "Pune", "customer_name": "Vikram Sharma", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.443254	t
803	ORDFEA16DA4F0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDFEA16DA4F0", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-10-14T17:30:00", "unit_price": 250.0, "customer_id": "C0398", "customer_city": "Thane", "customer_name": "Riya Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.443628	t
804	ORD80FD7EE114	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD80FD7EE114", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-10-01T14:23:00", "unit_price": 220.0, "customer_id": "C0174", "customer_city": "Mumbai", "customer_name": "Riya Kulkarni", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.443976	t
805	ORD234528DA7E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD234528DA7E", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-30T09:36:00", "unit_price": 250.0, "customer_id": "C0307", "customer_city": "Thane", "customer_name": "Sneha Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.44431	t
806	ORDE4A10DC00F	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORDE4A10DC00F", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-09-21T08:35:00", "unit_price": 380.0, "customer_id": "C0151", "customer_city": "Thane", "customer_name": "Pooja Sharma", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.444635	t
807	ORD9C9533EBC0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9C9533EBC0", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-07-29T13:16:00", "unit_price": 340.0, "customer_id": "C0084", "customer_city": "Thane", "customer_name": "Riya Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.445098	t
808	ORD4C5BE260E8	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4C5BE260E8", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-08-05T08:40:00", "unit_price": 250.0, "customer_id": "C0061", "customer_city": "Thane", "customer_name": "Anjali Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.445442	t
809	ORD27CE4682E0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD27CE4682E0", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-07-30T13:21:00", "unit_price": 340.0, "customer_id": "C0348", "customer_city": "Thane", "customer_name": "Rohan Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.445777	t
810	ORD81D7263516	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD81D7263516", "quantity": 3, "item_name": "French Fries", "order_time": "2026-07-24T13:18:00", "unit_price": 90.0, "customer_id": "C0256", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.446109	t
811	ORD5DEB07C359	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5DEB07C359", "quantity": 0, "item_name": "Butter Chicken", "order_time": "2026-08-26T21:59:00", "unit_price": 320.0, "customer_id": "C0350", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.44646	t
812	ORDCDF28AA950	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCDF28AA950", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-10-01T21:58:00", "unit_price": 60.0, "customer_id": "C0103", "customer_city": "MUMBAI", "customer_name": "  priya khan ", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.446792	t
813	ORDBE054C5DF7	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDBE054C5DF7", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-08-15T20:57:00", "unit_price": 120.0, "customer_id": "C0152", "customer_city": "Mumbai", "customer_name": "Anjali Sharma", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.447158	t
814	ORD077F3364A9	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD077F3364A9", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-09-05T16:44:00", "unit_price": 120.0, "customer_id": "C0092", "customer_city": "Mumbai", "customer_name": "Arjun Kulkarni", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.447746	t
815	ORDCD82BFCF89	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDCD82BFCF89", "quantity": 4, "item_name": "Idli Sambar", "order_time": "2026-08-26T16:59:00", "unit_price": 80.0, "customer_id": "C0211", "customer_city": "Pune", "customer_name": "Arjun Mehta", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.448181	t
816	ORD753DCD6FB0	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD753DCD6FB0", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-08-07T21:44:00", "unit_price": 280.0, "customer_id": "C0323", "customer_city": "Mumbai", "customer_name": "Priya Kulkarni", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.448524	t
817	ORD6F2698B4D2	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6F2698B4D2", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-31T19:25:00", "unit_price": 250.0, "customer_id": "C0344", "customer_city": "Thane", "customer_name": "Rohan Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.448854	t
818	ORD6FAA7C2CEB	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD6FAA7C2CEB", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-08-01T09:48:00", "unit_price": 299.0, "customer_id": "C0185", "customer_city": "Mumbai", "customer_name": "Rohan Mehta", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.449199	t
819	ORD67D981D2E4	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD67D981D2E4", "quantity": 2, "item_name": "Idli Sambar", "order_time": "2026-10-10T14:08:00", "unit_price": 80.0, "customer_id": "C0184", "customer_city": "Pune", "customer_name": "Priya Patil", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.449546	t
820	ORD330B3D0D2C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD330B3D0D2C", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-10-11T20:25:00", "unit_price": 55.0, "customer_id": "C0336", "customer_city": "Thane", "customer_name": "Riya Iyer", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.449875	t
821	ORDF8A8987BF7	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDF8A8987BF7", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-07-27T14:47:00", "unit_price": 220.0, "customer_id": "C0181", "customer_city": "Pune", "customer_name": "Rohan Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.45021	t
822	ORDE197AAA286	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDE197AAA286", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-09-18T21:19:00", "unit_price": 180.0, "customer_id": "C0163", "customer_city": "Mumbai", "customer_name": "Pooja Singh", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.450569	t
823	ORD432E8BE5AA	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD432E8BE5AA", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-08-09T12:50:00", "unit_price": 220.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.45089	t
824	ORD27CE4682E0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD27CE4682E0", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-07-30T13:21:00", "unit_price": 340.0, "customer_id": "C0348", "customer_city": "Thane", "customer_name": "Rohan Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.451194	t
825	ORD769299BC7B	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD769299BC7B", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-07-28T21:46:00", "unit_price": 340.0, "customer_id": "C0125", "customer_city": "Thane", "customer_name": "Sneha Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.451492	t
826	ORDE73136B356	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE73136B356", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-07-21T21:37:00", "unit_price": 380.0, "customer_id": "C0053", "customer_city": "Thane", "customer_name": "Rohan Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.451833	t
827	ORD7E5D7900F0	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD7E5D7900F0", "quantity": 3, "item_name": "Raita", "order_time": "2026-08-27T20:49:00", "unit_price": 40.0, "customer_id": "C0393", "customer_city": "Pune", "customer_name": "Priya Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.45215	t
828	ORD49998C77D2	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD49998C77D2", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-08-19T16:12:00", "unit_price": 140.0, "customer_id": "C0010", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.452459	t
829	ORDC6F9587BE7	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC6F9587BE7", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-07-20T13:17:00", "unit_price": 150.0, "customer_id": "C0300", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.452799	t
830	ORD5934F04E52	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD5934F04E52", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-09-18T13:16:00", "unit_price": 299.0, "customer_id": "C0327", "customer_city": "Mumbai", "customer_name": "Priya Joshi", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.453115	t
831	ORDA9675A5AA9	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA9675A5AA9", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-10-08T22:58:00", "unit_price": 380.0, "customer_id": "C0304", "customer_city": "THANE", "customer_name": "  sahil iyer ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.453443	t
832	ORD5EB16114B4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5EB16114B4", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-26T20:23:00", "unit_price": 340.0, "customer_id": "C0109", "customer_city": "THANE", "customer_name": "  sneha iyer ", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.453772	t
833	ORD6B17CDA851	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD6B17CDA851", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-10-02T21:19:00", "unit_price": 80.0, "customer_id": "C0145", "customer_city": "Pune", "customer_name": "Aarav Desai", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.454087	t
834	ORD87C785AAEE	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD87C785AAEE", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-08-10T20:44:00", "unit_price": 140.0, "customer_id": "C0359", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.454397	t
835	ORD04CB97EFF0	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD04CB97EFF0", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-10-02T21:19:00", "unit_price": 140.0, "customer_id": "C0364", "customer_city": "PUNE", "customer_name": "  arjun iyer ", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.454854	t
836	ORDF095100E56	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF095100E56", "quantity": 0, "item_name": "Paneer Butter Masala", "order_time": "2026-10-01T17:54:00", "unit_price": 250.0, "customer_id": "C0380", "customer_city": "Thane", "customer_name": "Pooja Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.455176	t
837	ORDEAC301E137	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDEAC301E137", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-09-21T21:57:00", "unit_price": 380.0, "customer_id": "C0044", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.455489	t
838	ORD4731BC4F41	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD4731BC4F41", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-09-15T19:06:00", "unit_price": 220.0, "customer_id": "C0256", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.455798	t
839	ORD34F71E3622	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD34F71E3622", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-08-09T21:44:00", "unit_price": 380.0, "customer_id": "C0042", "customer_city": "Thane", "customer_name": "Rohan Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.456135	t
840	ORD5DDDFA977B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5DDDFA977B", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-08-21T13:53:00", "unit_price": 250.0, "customer_id": "C0281", "customer_city": "Thane", "customer_name": "Neha Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.456453	t
841	ORDA40C19805F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA40C19805F", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-07-23T09:55:00", "unit_price": 80.0, "customer_id": "C0010", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.456762	t
842	ORD3A46549E09	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD3A46549E09", "quantity": 3, "item_name": "Raita", "order_time": "2026-08-24T21:05:00", "unit_price": 40.0, "customer_id": "C0342", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.457076	t
843	ORD4C26C4EFCD	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD4C26C4EFCD", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-09-29T21:07:00", "unit_price": 380.0, "customer_id": "C0147", "customer_city": "Thane", "customer_name": "Sneha Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.457409	t
844	ORDE588E384AD	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDE588E384AD", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-10-02T17:50:00", "unit_price": 220.0, "customer_id": "C0254", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.457738	t
845	ORDD161A710C2	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDD161A710C2", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-07-27T14:24:00", "unit_price": 280.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.458051	t
846	ORD18D3B313FA	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORD18D3B313FA", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-31T12:04:00", "unit_price": 350.0, "customer_id": "C0237", "customer_city": "Thane", "customer_name": "Priya Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.458366	t
847	ORD9CA3714810	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9CA3714810", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-23T21:53:00", "unit_price": 340.0, "customer_id": "C0057", "customer_city": "Thane", "customer_name": "Vikram Iyer", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.458672	t
848	ORD0B8A2899E8	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD0B8A2899E8", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-29T20:15:00", "unit_price": 220.0, "customer_id": "C0140", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.458993	t
849	ORD24ABF2D179	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD24ABF2D179", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-07-30T08:30:00", "unit_price": 210.0, "customer_id": "C0077", "customer_city": "Mumbai", "customer_name": "Riya Kulkarni", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.459315	t
850	ORDB4FF7765F8	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDB4FF7765F8", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-07-26T12:41:00", "unit_price": 150.0, "customer_id": "C0095", "customer_city": "THANE", "customer_name": "  riya nair ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.459641	t
851	ORDC4B1B06578	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDC4B1B06578", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-08-23T16:25:00", "unit_price": 280.0, "customer_id": "C0256", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.459966	t
852	ORD97BC003F5E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD97BC003F5E", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-09-22T14:14:00", "unit_price": 150.0, "customer_id": "C0305", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.460286	t
853	ORD0DF3AABDFA	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD0DF3AABDFA", "quantity": 2, "item_name": "Raita", "order_time": "2026-09-07T16:07:00", "unit_price": 40.0, "customer_id": "C0091", "customer_city": "Pune", "customer_name": "Neha Sharma", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.460615	t
854	ORD5A05CD4B45	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5A05CD4B45", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-10-06T22:12:00", "unit_price": 55.0, "customer_id": "C0131", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.460937	t
855	ORDB305E1ED48	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB305E1ED48", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-09-17T21:35:00", "unit_price": 180.0, "customer_id": "C0113", "customer_city": "Mumbai", "customer_name": "Anjali Singh", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.461233	t
856	ORDC41F2572D8	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC41F2572D8", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-09-24T20:25:00", "unit_price": 250.0, "customer_id": null, "customer_city": "Thane", "customer_name": "Neha Patil", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.461525	t
857	ORDC93E1DFE83	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC93E1DFE83", "quantity": 1, "item_name": "Dal Makhani", "order_time": "2026-08-27T21:09:00", "unit_price": 220.0, "customer_id": "C0233", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.461833	t
858	ORDBA2E116CD5	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDBA2E116CD5", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-27T22:47:00", "unit_price": 280.0, "customer_id": "C0339", "customer_city": "Mumbai", "customer_name": "Anjali Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.462138	t
859	ORD2F37DF131C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2F37DF131C", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-07-20T09:11:00", "unit_price": 350.0, "customer_id": "C0111", "customer_city": "Thane", "customer_name": "Priya Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.462443	t
860	ORD0DFA2AE610	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD0DFA2AE610", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-08-13T22:16:00", "unit_price": 210.0, "customer_id": "C0049", "customer_city": "Mumbai", "customer_name": "Aarav Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.462741	t
861	ORD748DD18A0E	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD748DD18A0E", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-08-19T21:19:00", "unit_price": 80.0, "customer_id": "C0297", "customer_city": "Pune", "customer_name": "Sneha Singh", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.463032	t
862	ORDBBCD92B390	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDBBCD92B390", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-21T21:42:00", "unit_price": 150.0, "customer_id": "C0307", "customer_city": "Thane", "customer_name": "Sneha Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.46333	t
863	ORDF455DF7C53	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF455DF7C53", "quantity": 4, "item_name": "Butter Chicken", "order_time": "2026-09-02T17:45:00", "unit_price": 320.0, "customer_id": "C0162", "customer_city": "Mumbai", "customer_name": "Vikram Sharma", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.463627	t
864	ORD5394BD7026	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5394BD7026", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-08-15T21:40:00", "unit_price": 260.0, "customer_id": "C0009", "customer_city": "Mumbai", "customer_name": "Pooja Singh", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.464108	t
865	ORD43759661D2	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD43759661D2", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-20T21:12:00", "unit_price": 150.0, "customer_id": "C0083", "customer_city": "Pune", "customer_name": "Rohan Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.464457	t
866	ORD4A62AF883D	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD4A62AF883D", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-07-20T12:24:00", "unit_price": 40.0, "customer_id": "C0241", "customer_city": "Pune", "customer_name": "Sneha Mehta", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.46476	t
867	ORD5F6C80FED8	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD5F6C80FED8", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-30T08:07:00", "unit_price": 380.0, "customer_id": "C0043", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.465099	t
868	ORDBD2D85F911	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDBD2D85F911", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-09-26T21:36:00", "unit_price": 150.0, "customer_id": "C0015", "customer_city": "Pune", "customer_name": "Kabir Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.465605	t
869	ORDA575B16B73	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA575B16B73", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-09-19T21:00:00", "unit_price": 250.0, "customer_id": "C0389", "customer_city": "Thane", "customer_name": "Pooja Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.466098	t
870	ORD37D1EDB900	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD37D1EDB900", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-10-06T13:43:00", "unit_price": 140.0, "customer_id": "C0364", "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.466443	t
871	ORD41F31AA5FE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD41F31AA5FE", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-10-02T22:15:00", "unit_price": 220.0, "customer_id": "C0134", "customer_city": "Mumbai", "customer_name": "Sneha Khan", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.46677	t
872	ORD0BDD534EE2	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0BDD534EE2", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-08-21T09:02:00", "unit_price": 340.0, "customer_id": "C0165", "customer_city": "Thane", "customer_name": "Sneha Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.467076	t
873	ORDF99183E717	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF99183E717", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-05T22:40:00", "unit_price": 350.0, "customer_id": "C0267", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.467407	t
874	ORDFF18756410	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDFF18756410", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-01T21:26:00", "unit_price": 280.0, "customer_id": "C0026", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.467724	t
875	ORDAA2A42F5C4	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAA2A42F5C4", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-07-29T17:08:00", "unit_price": 380.0, "customer_id": "C0392", "customer_city": "Thane", "customer_name": "Pooja Singh", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.46806	t
876	ORD458F5FAD4E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD458F5FAD4E", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-08-26T17:22:00", "unit_price": 150.0, "customer_id": "C0171", "customer_city": "THANE", "customer_name": "  sneha singh ", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.468365	t
877	ORD4FBBD2FDB5	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD4FBBD2FDB5", "quantity": 1, "item_name": "Masala Dosa", "order_time": "2026-09-12T14:41:00", "unit_price": 110.0, "customer_id": "C0364", "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.468686	t
878	ORD7131AA8D97	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD7131AA8D97", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-05T22:21:00", "unit_price": 150.0, "customer_id": "C0321", "customer_city": "Thane", "customer_name": "Pooja Nair", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.468991	t
879	ORDC76B6E2E57	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC76B6E2E57", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-08-07T20:51:00", "unit_price": 55.0, "customer_id": "C0316", "customer_city": "Thane", "customer_name": "Rohan Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.469306	t
880	ORDE81871B91F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE81871B91F", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-07-19T21:51:00", "unit_price": 150.0, "customer_id": "C0111", "customer_city": "THANE", "customer_name": "  priya kulkarni ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.469607	t
881	ORDA86C9E9FF6	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDA86C9E9FF6", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-09-13T16:25:00", "unit_price": 210.0, "customer_id": "C0073", "customer_city": "Mumbai", "customer_name": "Kabir Desai", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.469921	t
882	ORD81516B1002	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD81516B1002", "quantity": 1, "item_name": "Manchurian", "order_time": "2026-08-29T20:05:00", "unit_price": 210.0, "customer_id": "C0092", "customer_city": "Mumbai", "customer_name": "Arjun Kulkarni", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.470203	t
883	ORD62465643AA	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD62465643AA", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-07-20T22:14:00", "unit_price": -350.0, "customer_id": "C0324", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.470491	t
884	ORDB5FA5F8566	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB5FA5F8566", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-08-05T21:38:00", "unit_price": 220.0, "customer_id": "C0098", "customer_city": "Mumbai", "customer_name": "Anjali Sharma", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.470791	t
885	ORD4FEA53E518	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD4FEA53E518", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-08-17T13:17:00", "unit_price": 350.0, "customer_id": "C0228", "customer_city": "Thane", "customer_name": "Neha Iyer", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.471087	t
886	ORDFF6856E6D1	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDFF6856E6D1", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-09-26T12:36:00", "unit_price": 380.0, "customer_id": "C0116", "customer_city": "THANE", "customer_name": "  sneha desai ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.471386	t
887	ORD86A0E43882	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD86A0E43882", "quantity": 4, "item_name": "Pasta Alfredo", "order_time": "2026-08-24T12:48:00", "unit_price": 280.0, "customer_id": "C0242", "customer_city": "Mumbai", "customer_name": "Priya Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.471742	t
888	ORDC8CEF29301	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDC8CEF29301", "quantity": 0, "item_name": "Masala Dosa", "order_time": "2026-07-30T13:32:00", "unit_price": 110.0, "customer_id": "C0375", "customer_city": "Pune", "customer_name": "Arjun Nair", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.472044	t
889	ORD544AB37209	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD544AB37209", "quantity": 0, "item_name": "Veg Biryani", "order_time": "2026-08-18T08:24:00", "unit_price": 220.0, "customer_id": "C0368", "customer_city": "Pune", "customer_name": "Vikram Nair", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.472352	t
890	ORDA648CBA573	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA648CBA573", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-08-13T22:31:00", "unit_price": 250.0, "customer_id": "C0096", "customer_city": "Thane", "customer_name": "Sneha Patil", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.472661	t
891	ORD155D6F5735	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD155D6F5735", "quantity": 2, "item_name": "Raita", "order_time": "2026-09-23T19:17:00", "unit_price": 40.0, "customer_id": "C0241", "customer_city": "Pune", "customer_name": "Sneha Mehta", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.472954	t
892	ORD799F85D5D3	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD799F85D5D3", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-08-31T14:46:00", "unit_price": 140.0, "customer_id": "C0376", "customer_city": "Pune", "customer_name": "Arjun Sharma", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.47326	t
893	ORD901EA44EE0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD901EA44EE0", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-10T16:20:00", "unit_price": 250.0, "customer_id": "C0314", "customer_city": "Thane", "customer_name": "Priya Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.473663	t
894	ORDCB75A4C34A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDCB75A4C34A", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-07-26T19:58:00", "unit_price": 380.0, "customer_id": "C0099", "customer_city": "Thane", "customer_name": "Vikram Joshi", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.473966	t
895	ORD3B0383B00D	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD3B0383B00D", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-09-22T14:54:00", "unit_price": 280.0, "customer_id": "C0158", "customer_city": "Pune", "customer_name": "Riya Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.474255	t
896	ORDEFBC75B4B5	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDEFBC75B4B5", "quantity": 1, "item_name": "Raita", "order_time": "2026-07-22T13:50:00", "unit_price": 40.0, "customer_id": "C0175", "customer_city": "Pune", "customer_name": "Kabir Sharma", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.474559	t
897	ORDF43670B477	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF43670B477", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-07-23T20:18:00", "unit_price": 340.0, "customer_id": "C0283", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.474869	t
898	ORD511626FC3B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD511626FC3B", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-16T22:28:00", "unit_price": 150.0, "customer_id": "C0277", "customer_city": "Thane", "customer_name": "Priya Nair", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.475162	t
899	ORD797ECC98A6	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD797ECC98A6", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-08-09T13:34:00", "unit_price": 140.0, "customer_id": "C0246", "customer_city": "Pune", "customer_name": "Riya Khan", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.475456	t
900	ORD3869B187BE	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD3869B187BE", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-16T19:51:00", "unit_price": 250.0, "customer_id": "C0212", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.475773	t
901	ORD0E5389667A	{"status": "CANCELLED", "cuisine": "Italian", "order_id": "ORD0E5389667A", "quantity": 3, "item_name": "Pasta Alfredo", "order_time": "2026-10-08T09:51:00", "unit_price": 280.0, "customer_id": "C0293", "customer_city": "Mumbai", "customer_name": "Anjali Patil", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.476072	t
902	ORD2C2F1FDF69	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD2C2F1FDF69", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-08-30T20:07:00", "unit_price": 250.0, "customer_id": "C0215", "customer_city": "Thane", "customer_name": "Pooja Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.476377	t
903	ORDF7BD40164A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF7BD40164A", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-09-18T16:22:00", "unit_price": 340.0, "customer_id": "C0035", "customer_city": "Thane", "customer_name": "Arjun Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.476685	t
904	ORDB7BED73D15	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB7BED73D15", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-08-08T16:56:00", "unit_price": 55.0, "customer_id": "C0128", "customer_city": "Thane", "customer_name": "Pooja Desai", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.477012	t
905	ORDA370E47214	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDA370E47214", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-10-08T17:29:00", "unit_price": 220.0, "customer_id": "C0014", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.477313	t
906	ORDA8E7F5CFBA	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA8E7F5CFBA", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-10-10T17:21:00", "unit_price": 150.0, "customer_id": "C0120", "customer_city": "Thane", "customer_name": "Priya Mehta", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.477616	t
907	ORD1EE130C934	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD1EE130C934", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-08-20T08:19:00", "unit_price": 280.0, "customer_id": "C0138", "customer_city": "Pune", "customer_name": "Aarav Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.477914	t
908	ORDF1168A38BB	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF1168A38BB", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-08-13T19:00:00", "unit_price": 150.0, "customer_id": "C0107", "customer_city": "Thane", "customer_name": "Aarav Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.478248	t
909	ORD015EFB3060	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD015EFB3060", "quantity": 3, "item_name": "Butter Chicken", "order_time": "2026-10-04T08:47:00", "unit_price": 320.0, "customer_id": "C0021", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.478555	t
910	ORD40AF669F5F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD40AF669F5F", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-09-14T08:21:00", "unit_price": 350.0, "customer_id": "C0099", "customer_city": "Thane", "customer_name": "Vikram Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.478858	t
911	ORD8E4FAF5BAF	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD8E4FAF5BAF", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-07-30T16:37:00", "unit_price": 299.0, "customer_id": "C0163", "customer_city": "Mumbai", "customer_name": "Pooja Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.479149	t
912	ORDBFB599D8C7	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDBFB599D8C7", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-20T13:32:00", "unit_price": 380.0, "customer_id": "C0132", "customer_city": "Thane", "customer_name": "Sahil Mehta", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.479451	t
913	ORD71D5C99AD5	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD71D5C99AD5", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-09-10T14:19:00", "unit_price": 80.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Arjun Mehta", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.479748	t
914	ORD5BB6879D37	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD5BB6879D37", "quantity": 4, "item_name": "Raita", "order_time": "2026-08-09T19:36:00", "unit_price": 40.0, "customer_id": "C0376", "customer_city": "PUNE", "customer_name": "  arjun sharma ", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.48005	t
915	ORDCD20765BC7	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORDCD20765BC7", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-10-12T14:09:00", "unit_price": 220.0, "customer_id": "C0350", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.480373	t
916	ORDC265BA3C3B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC265BA3C3B", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-08-19T12:04:00", "unit_price": -60.0, "customer_id": "C0272", "customer_city": "Mumbai", "customer_name": "Sneha Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.480711	t
917	ORD6E5EEA4E86	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD6E5EEA4E86", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-08-14T20:27:00", "unit_price": 110.0, "customer_id": "C0130", "customer_city": "Pune", "customer_name": "Sahil Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.481017	t
918	ORDC9C2127FDC	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDC9C2127FDC", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-08-30T21:21:00", "unit_price": 80.0, "customer_id": "C0227", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.481319	t
919	ORD156027CAD6	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD156027CAD6", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-08-26T17:16:00", "unit_price": 120.0, "customer_id": "C0039", "customer_city": "Mumbai", "customer_name": "Aarav Iyer", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.481623	t
920	ORDD437DF4CB0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD437DF4CB0", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-07-30T17:21:00", "unit_price": 250.0, "customer_id": "C0044", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.482123	t
921	ORDF459BB1014	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORDF459BB1014", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-08-27T08:32:00", "unit_price": 80.0, "customer_id": "C0318", "customer_city": "Pune", "customer_name": "Vikram Sharma", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.482582	t
922	ORD3EF0D0A0D2	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD3EF0D0A0D2", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-09-17T14:18:00", "unit_price": 180.0, "customer_id": "C0288", "customer_city": "MUMBAI", "customer_name": "  anjali nair ", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.483072	t
923	ORDB090ED137F	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDB090ED137F", "quantity": 2, "item_name": "Chicken Biryani", "order_time": "2026-10-10T13:54:00", "unit_price": 280.0, "customer_id": "C0376", "customer_city": "Pune", "customer_name": "Arjun Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.483412	t
924	ORDE294E2F958	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE294E2F958", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-11T08:58:00", "unit_price": 380.0, "customer_id": "C0212", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.483733	t
925	ORD8B9DB027A0	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD8B9DB027A0", "quantity": 4, "item_name": "Raita", "order_time": "2026-08-17T21:40:00", "unit_price": 40.0, "customer_id": "C0191", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.484047	t
926	ORD4EDC0D058E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD4EDC0D058E", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-09-13T14:48:00", "unit_price": 350.0, "customer_id": "C0084", "customer_city": "Thane", "customer_name": "Riya Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.484341	t
927	ORD7C3C56BC74	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD7C3C56BC74", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-09-04T16:06:00", "unit_price": 150.0, "customer_id": "C0196", "customer_city": "Thane", "customer_name": "Vikram Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.484653	t
928	ORD3A299D4FAD	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD3A299D4FAD", "quantity": 4, "item_name": "Idli Sambar", "order_time": "2026-07-23T20:15:00", "unit_price": 80.0, "customer_id": "C0144", "customer_city": "Pune", "customer_name": "Neha Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.484965	t
929	ORDFC64F0B375	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDFC64F0B375", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-08-13T19:46:00", "unit_price": 280.0, "customer_id": "C0365", "customer_city": "Mumbai", "customer_name": "Rohan Singh", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.485278	t
930	ORD42D03AD536	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD42D03AD536", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-09-19T21:23:00", "unit_price": 380.0, "customer_id": "C0081", "customer_city": "Thane", "customer_name": "Neha Mehta", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.485591	t
931	ORD5D32B402F6	{"status": "PLACED", "cuisine": "South Indian", "order_id": "ORD5D32B402F6", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-10-10T20:32:00", "unit_price": 40.0, "customer_id": "C0320", "customer_city": "PUNE", "customer_name": "  priya desai ", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.485898	t
932	ORD3A331473DD	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3A331473DD", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-01T17:47:00", "unit_price": 340.0, "customer_id": "C0330", "customer_city": "Thane", "customer_name": "Vikram Singh", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.486196	t
933	ORD464BD6B36F	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD464BD6B36F", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-09-19T22:45:00", "unit_price": 140.0, "customer_id": "C0379", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.4865	t
934	ORD306803D2D4	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD306803D2D4", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-10-10T17:01:00", "unit_price": 180.0, "customer_id": "C0293", "customer_city": "Mumbai", "customer_name": "Anjali Patil", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.486802	t
935	ORD1DB03736F7	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD1DB03736F7", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-08-16T14:03:00", "unit_price": 280.0, "customer_id": "C0040", "customer_city": "Mumbai", "customer_name": "Sneha Kulkarni", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.487099	t
936	ORDE10A675F6C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE10A675F6C", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-08-24T21:38:00", "unit_price": 150.0, "customer_id": "C0337", "customer_city": "Thane", "customer_name": "Kabir Mehta", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.487396	t
937	ORD88A02EC3D4	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD88A02EC3D4", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-09-28T21:19:00", "unit_price": 299.0, "customer_id": "C0140", "customer_city": "Mumbai", "customer_name": "Sneha Mehta", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.487693	t
938	ORD9562C3296C	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD9562C3296C", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-08-14T19:37:00", "unit_price": 55.0, "customer_id": "C0265", "customer_city": "Thane", "customer_name": "Vikram Sharma", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.488024	t
939	ORD94D6B9EEB7	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD94D6B9EEB7", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-09-01T17:39:00", "unit_price": 150.0, "customer_id": "C0171", "customer_city": "Thane", "customer_name": "Sneha Singh", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.488326	t
940	ORD931C00DB7E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD931C00DB7E", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-17T21:56:00", "unit_price": 340.0, "customer_id": "C0137", "customer_city": "Thane", "customer_name": "Neha Iyer", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.488624	t
941	ORDD051E7496E	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDD051E7496E", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-09-03T20:31:00", "unit_price": 150.0, "customer_id": "C0324", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.488929	t
942	ORDC1A20F0CB6	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC1A20F0CB6", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-08-30T08:43:00", "unit_price": 60.0, "customer_id": "C0293", "customer_city": "Mumbai", "customer_name": "Anjali Patil", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.489219	t
943	ORDD2B22A7889	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD2B22A7889", "quantity": 4, "item_name": "Butter Chicken", "order_time": "2026-09-04T13:47:00", "unit_price": 320.0, "customer_id": "C0298", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.489541	t
944	ORD2AC76B4008	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD2AC76B4008", "quantity": 3, "item_name": "Hakka Noodles", "order_time": "2026-09-20T19:15:00", "unit_price": 190.0, "customer_id": "C0058", "customer_city": "MUMBAI", "customer_name": "  vikram patil ", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.489846	t
945	ORD21B2B756A0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD21B2B756A0", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-10-08T13:39:00", "unit_price": 250.0, "customer_id": "C0382", "customer_city": "THANE", "customer_name": "  rohan iyer ", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.490139	t
946	ORD7FA2C3DB34	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD7FA2C3DB34", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-08-27T14:52:00", "unit_price": 340.0, "customer_id": "C0178", "customer_city": "Thane", "customer_name": "Kabir Sharma", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.49043	t
947	ORD68A96B6989	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD68A96B6989", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-23T14:50:00", "unit_price": 380.0, "customer_id": "C0125", "customer_city": "Thane", "customer_name": "Sneha Desai", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.490753	t
948	ORD962BB9C2FD	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD962BB9C2FD", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-09-09T16:46:00", "unit_price": 260.0, "customer_id": "C0252", "customer_city": "Mumbai", "customer_name": "Kabir Sharma", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.491053	t
949	ORD465D5E8486	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD465D5E8486", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-08-22T12:17:00", "unit_price": 320.0, "customer_id": "C0290", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.49135	t
950	ORDE342585FE4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE342585FE4", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-08-06T17:39:00", "unit_price": 250.0, "customer_id": "C0292", "customer_city": "Thane", "customer_name": "Pooja Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.491645	t
951	ORDC8AFACDCBF	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC8AFACDCBF", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-07-27T13:12:00", "unit_price": 220.0, "customer_id": "C0236", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.492066	t
952	ORD6FC108BEC5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD6FC108BEC5", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-09-21T22:12:00", "unit_price": 250.0, "customer_id": "C0358", "customer_city": "Thane", "customer_name": "Anjali Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.492363	t
953	ORD95C4BDA9F0	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD95C4BDA9F0", "quantity": 3, "item_name": "Raita", "order_time": "2026-09-17T13:38:00", "unit_price": 40.0, "customer_id": "C0208", "customer_city": "Pune", "customer_name": "Neha Singh", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.492663	t
954	ORDBD38A8296C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDBD38A8296C", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-08-18T13:58:00", "unit_price": 150.0, "customer_id": "C0281", "customer_city": "Thane", "customer_name": "Neha Desai", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.493004	t
955	ORD766F878D92	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD766F878D92", "quantity": 1, "item_name": "Margherita Pizza", "order_time": "2026-10-06T21:10:00", "unit_price": 299.0, "customer_id": "C0073", "customer_city": "MUMBAI", "customer_name": "  kabir desai ", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.493302	t
956	ORDABB4EE1EC4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDABB4EE1EC4", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-09-10T19:35:00", "unit_price": 250.0, "customer_id": "C0089", "customer_city": "Thane", "customer_name": "Arjun Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.493615	t
957	ORDECDBB88E45	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDECDBB88E45", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-10-03T20:43:00", "unit_price": 150.0, "customer_id": "C0102", "customer_city": "Pune", "customer_name": "Sahil Khan", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.493911	t
958	ORDFFCD82E1A1	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDFFCD82E1A1", "quantity": 2, "item_name": "Raita", "order_time": "2026-08-17T21:35:00", "unit_price": 40.0, "customer_id": "C0208", "customer_city": "PUNE", "customer_name": "  neha singh ", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.494229	t
959	ORD1D60C4D915	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD1D60C4D915", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-09-02T21:11:00", "unit_price": 250.0, "customer_id": "C0025", "customer_city": "Thane", "customer_name": "Sneha Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.494522	t
960	ORDB72CEC9ED8	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDB72CEC9ED8", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-08-18T19:58:00", "unit_price": 80.0, "customer_id": "C0010", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.494848	t
961	ORD990EBB9698	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD990EBB9698", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-10-09T20:48:00", "unit_price": 260.0, "customer_id": "C0360", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.495141	t
962	ORDC3B6E1F197	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDC3B6E1F197", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-20T13:12:00", "unit_price": 350.0, "customer_id": "C0348", "customer_city": "Thane", "customer_name": "Rohan Khan", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.495439	t
963	ORD06676AF1AE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD06676AF1AE", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-09-21T20:36:00", "unit_price": 250.0, "customer_id": "C0304", "customer_city": "THANE", "customer_name": "  sahil iyer ", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.495747	t
964	ORDFCE1D94B2A	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDFCE1D94B2A", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-08-21T21:11:00", "unit_price": 220.0, "customer_id": "C0345", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.496045	t
965	ORD75F1BDADEA	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD75F1BDADEA", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-09-17T22:33:00", "unit_price": 299.0, "customer_id": "C0373", "customer_city": "Mumbai", "customer_name": "Anjali Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.49635	t
966	ORDAF16440C77	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDAF16440C77", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-10-04T19:58:00", "unit_price": 110.0, "customer_id": "C0002", "customer_city": "Pune", "customer_name": "Rohan Singh", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.496647	t
967	ORD109B97C8D7	{"status": "PLACED", "cuisine": "Hyderabadi", "order_id": "ORD109B97C8D7", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-10-09T20:42:00", "unit_price": 220.0, "customer_id": "C0246", "customer_city": "Pune", "customer_name": "Riya Khan", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.496943	t
968	ORDF17B4F47AA	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDF17B4F47AA", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-10-04T13:18:00", "unit_price": 140.0, "customer_id": "C0251", "customer_city": "Pune", "customer_name": "Riya Nair", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.497243	t
969	ORD90F8BAEC52	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD90F8BAEC52", "quantity": 2, "item_name": "Garlic Bread", "order_time": "2026-10-10T21:34:00", "unit_price": 120.0, "customer_id": "C0346", "customer_city": "Mumbai", "customer_name": "Priya Iyer", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.497638	t
970	ORD39C88C22C7	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD39C88C22C7", "quantity": 3, "item_name": "Fried Rice", "order_time": "2026-09-12T16:30:00", "unit_price": 180.0, "customer_id": "C0258", "customer_city": "Mumbai", "customer_name": "Arjun Singh", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.498118	t
971	ORDDCF79E6AF7	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDDCF79E6AF7", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-10-02T20:30:00", "unit_price": 350.0, "customer_id": "C0089", "customer_city": "Thane", "customer_name": "Arjun Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.498417	t
972	ORD51FBF1075B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD51FBF1075B", "quantity": 1, "item_name": "Butter Naan", "order_time": "2026-09-25T22:11:00", "unit_price": 55.0, "customer_id": "C0392", "customer_city": "Thane", "customer_name": "Pooja Singh", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.49905	t
973	ORD2D5C88EEED	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD2D5C88EEED", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-26T12:49:00", "unit_price": 150.0, "customer_id": "C0046", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.499547	t
974	ORDE240EB37DE	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE240EB37DE", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-08T13:32:00", "unit_price": -150.0, "customer_id": "C0317", "customer_city": "Pune", "customer_name": "Sahil Desai", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.499889	t
975	ORDA23F1AB1C6	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA23F1AB1C6", "quantity": 3, "item_name": "Paneer Tikka", "order_time": "2026-08-14T14:36:00", "unit_price": 260.0, "customer_id": "C0188", "customer_city": "Mumbai", "customer_name": "Riya Iyer", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.500222	t
976	ORDB15284EC62	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDB15284EC62", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-03T20:54:00", "unit_price": 150.0, "customer_id": "C0135", "customer_city": "Pune", "customer_name": "Neha Sharma", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.500542	t
977	ORD978DCE907E	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD978DCE907E", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-07-25T12:12:00", "unit_price": 120.0, "customer_id": "C0287", "customer_city": "Mumbai", "customer_name": "Aarav Kulkarni", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.500853	t
978	ORD39EE710187	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD39EE710187", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-10-10T12:35:00", "unit_price": 220.0, "customer_id": "C0224", "customer_city": "Mumbai", "customer_name": "Neha Joshi", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.501402	t
979	ORD0A6876B269	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0A6876B269", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-10-14T13:13:00", "unit_price": 60.0, "customer_id": "C0236", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.501712	t
980	ORDF29569C08C	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDF29569C08C", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-07-21T17:49:00", "unit_price": 220.0, "customer_id": "C0105", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.502046	t
981	ORD71D10806C1	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD71D10806C1", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-14T19:07:00", "unit_price": 340.0, "customer_id": "C0267", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.502346	t
982	ORD8E39E6479C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD8E39E6479C", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-08-25T20:54:00", "unit_price": 250.0, "customer_id": "C0160", "customer_city": "Thane", "customer_name": "Aarav Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.502659	t
983	ORD23C4AE67D0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD23C4AE67D0", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-16T12:37:00", "unit_price": 250.0, "customer_id": "C0333", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.502972	t
984	ORD9052490BCE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9052490BCE", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-08-07T12:29:00", "unit_price": 55.0, "customer_id": "C0344", "customer_city": "Thane", "customer_name": "Rohan Patil", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.503271	t
985	ORD012D8D4120	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD012D8D4120", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-08-10T08:38:00", "unit_price": 380.0, "customer_id": "C0141", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.503586	t
986	ORDF4F2066CE4	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDF4F2066CE4", "quantity": 3, "item_name": "Filter Coffee", "order_time": "2026-10-13T20:04:00", "unit_price": 40.0, "customer_id": "C0206", "customer_city": "Pune", "customer_name": "Sneha Nair", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.503895	t
987	ORD0A2F30B02C	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD0A2F30B02C", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-08-18T19:26:00", "unit_price": 80.0, "customer_id": "C0066", "customer_city": "Pune", "customer_name": "Kabir Patil", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.504188	t
988	ORDBC722FB088	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDBC722FB088", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-09-09T13:13:00", "unit_price": 190.0, "customer_id": "C0248", "customer_city": "Mumbai", "customer_name": "Vikram Joshi", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.504487	t
989	ORDEF44303CBC	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEF44303CBC", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-08-13T16:21:00", "unit_price": 220.0, "customer_id": "C0162", "customer_city": "Mumbai", "customer_name": "Vikram Sharma", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.504817	t
990	ORDE294E2F958	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE294E2F958", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-11T08:58:00", "unit_price": 380.0, "customer_id": "C0212", "customer_city": "Thane", "customer_name": "Aarav Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.505129	t
991	ORDB404A8169B	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB404A8169B", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-09-10T09:02:00", "unit_price": 340.0, "customer_id": "C0151", "customer_city": "Thane", "customer_name": "Pooja Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.505434	t
992	ORDF7A1D63C06	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDF7A1D63C06", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-08-18T17:16:00", "unit_price": 220.0, "customer_id": "C0309", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.505737	t
993	ORD751524C84E	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD751524C84E", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-10-08T14:55:00", "unit_price": 340.0, "customer_id": "C0016", "customer_city": "Thane", "customer_name": "Vikram Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.506033	t
994	ORDCB7380EDDF	{"status": "PLACED", "cuisine": "Japanese", "order_id": "ORDCB7380EDDF", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-09-14T14:55:00", "unit_price": 350.0, "customer_id": "C0366", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.506329	t
995	ORDA5522A51D8	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDA5522A51D8", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-18T16:59:00", "unit_price": 150.0, "customer_id": "C0303", "customer_city": "Thane", "customer_name": "Sneha Iyer", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.506627	t
996	ORDED3B68DA69	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDED3B68DA69", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-10-07T17:16:00", "unit_price": 380.0, "customer_id": "C0354", "customer_city": "Thane", "customer_name": "Rohan Mehta", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.506934	t
997	ORDA7D02E6E80	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA7D02E6E80", "quantity": 3, "item_name": "Masala Dosa", "order_time": "2026-10-05T22:09:00", "unit_price": 110.0, "customer_id": "C0216", "customer_city": "Pune", "customer_name": "Neha Khan", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.507253	t
998	ORD79A1E41F3E	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD79A1E41F3E", "quantity": 4, "item_name": "Margherita Pizza", "order_time": "2026-08-02T14:18:00", "unit_price": 299.0, "customer_id": "C0339", "customer_city": "Mumbai", "customer_name": "Anjali Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.507539	t
999	ORD24DDF8D277	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD24DDF8D277", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-08-05T13:00:00", "unit_price": 150.0, "customer_id": "C0320", "customer_city": "Pune", "customer_name": "Priya Desai", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.507824	t
1000	ORD43C4B63399	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD43C4B63399", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-07-29T20:23:00", "unit_price": 220.0, "customer_id": "C0351", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.508126	t
1001	ORD20FB62FF35	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD20FB62FF35", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-07-20T13:35:00", "unit_price": 60.0, "customer_id": "C0284", "customer_city": "Mumbai", "customer_name": "Neha Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.508416	t
1002	ORD0F97639465	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD0F97639465", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-08-06T14:47:00", "unit_price": 299.0, "customer_id": "C0209", "customer_city": "MUMBAI", "customer_name": "  priya iyer ", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.508708	t
1003	ORD40FDD4C9DC	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD40FDD4C9DC", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-09-07T09:32:00", "unit_price": 250.0, "customer_id": "C0115", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.509006	t
1004	ORD1DBB9666D9	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD1DBB9666D9", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-09-25T17:37:00", "unit_price": 120.0, "customer_id": "C0101", "customer_city": "Mumbai", "customer_name": "Kabir Iyer", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.50932	t
1005	ORD668B661F60	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD668B661F60", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-09-19T13:19:00", "unit_price": 150.0, "customer_id": "C0388", "customer_city": "Thane", "customer_name": "Vikram Patil", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.509641	t
1006	ORD84AC5898FF	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD84AC5898FF", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-14T08:30:00", "unit_price": 340.0, "customer_id": "C0307", "customer_city": "Thane", "customer_name": "Sneha Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.509951	t
1007	ORDA257D52115	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA257D52115", "quantity": 0, "item_name": "Idli Sambar", "order_time": "2026-09-22T09:44:00", "unit_price": 80.0, "customer_id": "C0200", "customer_city": "Pune", "customer_name": "Riya Iyer", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.510474	t
1008	ORD45B659484F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD45B659484F", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-29T12:17:00", "unit_price": 250.0, "customer_id": "C0267", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.510784	t
1009	ORD075BF30DC4	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD075BF30DC4", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-09-29T21:14:00", "unit_price": 80.0, "customer_id": "C0068", "customer_city": "Pune", "customer_name": "Neha Patil", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.511085	t
1010	ORDD411DAC307	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD411DAC307", "quantity": 1, "item_name": "Butter Chicken", "order_time": "2026-08-16T20:36:00", "unit_price": 320.0, "customer_id": "C0329", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.51139	t
1011	ORDCCEA044091	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDCCEA044091", "quantity": 1, "item_name": "Chicken Biryani", "order_time": "2026-09-22T21:30:00", "unit_price": 280.0, "customer_id": "C0180", "customer_city": "Pune", "customer_name": "Priya Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.511695	t
1012	ORD47949BAE2F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD47949BAE2F", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-09-22T22:01:00", "unit_price": 380.0, "customer_id": "C0321", "customer_city": "Thane", "customer_name": "Pooja Nair", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.511994	t
1013	ORD33490C594F	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD33490C594F", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-10-01T17:25:00", "unit_price": 140.0, "customer_id": "C0145", "customer_city": "Pune", "customer_name": "Aarav Desai", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.512296	t
1014	ORDE6F9FBC61A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE6F9FBC61A", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-27T13:15:00", "unit_price": 380.0, "customer_id": "C0176", "customer_city": "Thane", "customer_name": "Kabir Kulkarni", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.512615	t
1015	ORD17A50F36EA	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD17A50F36EA", "quantity": 2, "item_name": "Cheese Burger", "order_time": "2026-07-19T09:03:00", "unit_price": 150.0, "customer_id": "C0239", "customer_city": "Pune", "customer_name": "Sneha Desai", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.512914	t
1016	ORDA5DF85DACC	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDA5DF85DACC", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-10-07T21:04:00", "unit_price": 280.0, "customer_id": "C0158", "customer_city": "Pune", "customer_name": "Riya Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.513207	t
1017	ORDFF18756410	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDFF18756410", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-01T21:26:00", "unit_price": 280.0, "customer_id": "C0026", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.513501	t
1018	ORDFE6B8B04B8	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDFE6B8B04B8", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-09-12T09:00:00", "unit_price": 140.0, "customer_id": "C0379", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.513817	t
1019	ORDFFAAE84580	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDFFAAE84580", "quantity": 3, "item_name": "Margherita Pizza", "order_time": "2026-10-07T13:07:00", "unit_price": 299.0, "customer_id": "C0092", "customer_city": "MUMBAI", "customer_name": "  arjun kulkarni ", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.514189	t
1020	ORDAE59B734DF	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAE59B734DF", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-09-01T22:28:00", "unit_price": 340.0, "customer_id": "C0034", "customer_city": "Thane", "customer_name": "Neha Mehta", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.514661	t
1021	ORD842616A6BD	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD842616A6BD", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-09-11T13:40:00", "unit_price": 60.0, "customer_id": "C0236", "customer_city": "Mumbai", "customer_name": "Arjun Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.515056	t
1022	ORD242CB92D6A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD242CB92D6A", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-07-19T20:58:00", "unit_price": 350.0, "customer_id": "C0215", "customer_city": "Thane", "customer_name": "Pooja Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.515608	t
1023	ORDC2943EA522	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC2943EA522", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-14T21:33:00", "unit_price": 250.0, "customer_id": "C0114", "customer_city": "Thane", "customer_name": "Kabir Kulkarni", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.516093	t
1024	ORD30ACED223C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD30ACED223C", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-10-01T13:56:00", "unit_price": 210.0, "customer_id": "C0339", "customer_city": "Mumbai", "customer_name": "Anjali Nair", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.516414	t
1025	ORDF9E14D4468	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF9E14D4468", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-10-07T12:34:00", "unit_price": 340.0, "customer_id": "C0153", "customer_city": "Thane", "customer_name": "Vikram Patil", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.516738	t
1026	ORDE047C498B3	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDE047C498B3", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-07-25T08:33:00", "unit_price": 250.0, "customer_id": "C0107", "customer_city": "Thane", "customer_name": "Aarav Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.517057	t
1027	ORD16BB5E0606	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD16BB5E0606", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-08-04T14:55:00", "unit_price": 280.0, "customer_id": "C0158", "customer_city": "Pune", "customer_name": "Riya Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.51738	t
1028	ORD650763E3EA	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD650763E3EA", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-08-25T13:33:00", "unit_price": 55.0, "customer_id": "C0325", "customer_city": "Thane", "customer_name": "Arjun Kulkarni", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.517706	t
1029	ORD15C097ABAE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD15C097ABAE", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-09-11T13:18:00", "unit_price": 55.0, "customer_id": "C0117", "customer_city": "Thane", "customer_name": "Pooja Nair", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.518034	t
1030	ORD46046BCD31	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD46046BCD31", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-09-25T09:18:00", "unit_price": 40.0, "customer_id": "C0393", "customer_city": "Pune", "customer_name": "Priya Joshi", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.51834	t
1031	ORDCD01D435BE	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDCD01D435BE", "quantity": 2, "item_name": "Margherita Pizza", "order_time": "2026-09-26T17:12:00", "unit_price": 299.0, "customer_id": "C0085", "customer_city": "Mumbai", "customer_name": "Sneha Kulkarni", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.518644	t
1032	ORD60B74C09CB	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD60B74C09CB", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-10-07T19:43:00", "unit_price": 250.0, "customer_id": "C0051", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.518947	t
1033	ORD968234B72C	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORD968234B72C", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-08-14T20:32:00", "unit_price": 150.0, "customer_id": "C0042", "customer_city": "THANE", "customer_name": "  rohan desai ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.519272	t
1034	ORDA67D63B008	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDA67D63B008", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-10-03T14:46:00", "unit_price": 150.0, "customer_id": "C0221", "customer_city": "Pune", "customer_name": "Arjun Nair", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.519573	t
1035	ORD73BF55CE5C	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD73BF55CE5C", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-07-22T22:54:00", "unit_price": 150.0, "customer_id": "C0328", "customer_city": "Pune", "customer_name": "Vikram Joshi", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.519886	t
1036	ORD2EF9957337	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD2EF9957337", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-08-29T13:10:00", "unit_price": 280.0, "customer_id": "C0233", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.520355	t
1037	ORD94B1D5B2DB	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD94B1D5B2DB", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-09-27T14:42:00", "unit_price": 150.0, "customer_id": "C0392", "customer_city": "Thane", "customer_name": "Pooja Singh", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.520661	t
1038	ORDDEFF8F1651	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDDEFF8F1651", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-10-01T08:44:00", "unit_price": 80.0, "customer_id": "C0066", "customer_city": "Pune", "customer_name": "Kabir Patil", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.520983	t
1039	ORDD81CF69A80	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORDD81CF69A80", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-04T20:25:00", "unit_price": 150.0, "customer_id": "C0124", "customer_city": "Thane", "customer_name": "Vikram Desai", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.521294	t
1040	ORDC25ACB27EE	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC25ACB27EE", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-08-08T17:45:00", "unit_price": 140.0, "customer_id": "C0006", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.521583	t
1041	ORD85ACE9C35B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD85ACE9C35B", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-08-23T19:14:00", "unit_price": 380.0, "customer_id": "C0117", "customer_city": "Thane", "customer_name": "Pooja Nair", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.521877	t
1042	ORDE120FE7453	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE120FE7453", "quantity": 1, "item_name": "Garlic Bread", "order_time": "2026-09-08T09:04:00", "unit_price": 120.0, "customer_id": "C0073", "customer_city": "MUMBAI", "customer_name": "  kabir desai ", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.522176	t
1043	ORD1F20427A31	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD1F20427A31", "quantity": 4, "item_name": "Masala Dosa", "order_time": "2026-08-03T22:49:00", "unit_price": 110.0, "customer_id": "C0328", "customer_city": "PUNE", "customer_name": "  vikram joshi ", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.522472	t
1044	ORD3C32457BFC	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD3C32457BFC", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-08-17T17:58:00", "unit_price": 220.0, "customer_id": "C0282", "customer_city": "Pune", "customer_name": "Priya Singh", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.522782	t
1045	ORDD838345C69	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDD838345C69", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-08-26T21:12:00", "unit_price": 220.0, "customer_id": "C0275", "customer_city": "Pune", "customer_name": "Rohan Nair", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.523084	t
1046	ORDB5BB71D166	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB5BB71D166", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-07-21T08:38:00", "unit_price": 60.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.523375	t
1047	ORDBCDD1F297C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDBCDD1F297C", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-09-10T13:05:00", "unit_price": 380.0, "customer_id": "C0307", "customer_city": "THANE", "customer_name": "  sneha khan ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.523665	t
1048	ORDA3ADBC9309	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDA3ADBC9309", "quantity": 2, "item_name": "Tandoori Chicken", "order_time": "2026-08-25T13:32:00", "unit_price": 340.0, "customer_id": "C0332", "customer_city": "Thane", "customer_name": "Riya Iyer", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.523961	t
1049	ORD28E842AA24	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD28E842AA24", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-07-30T20:53:00", "unit_price": 350.0, "customer_id": "C0109", "customer_city": "Thane", "customer_name": "Sneha Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.524261	t
1050	ORDE859889586	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE859889586", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-08-10T16:43:00", "unit_price": 350.0, "customer_id": "C0325", "customer_city": "THANE", "customer_name": "  arjun kulkarni ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.524569	t
1051	ORD0B78DD260C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD0B78DD260C", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-09-28T17:30:00", "unit_price": -350.0, "customer_id": "C0081", "customer_city": "Thane", "customer_name": "Neha Mehta", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.524865	t
1052	ORD63427E73F9	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD63427E73F9", "quantity": 2, "item_name": "French Fries", "order_time": "2026-10-13T17:42:00", "unit_price": 90.0, "customer_id": "C0244", "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.525151	t
1053	ORD5156931665	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5156931665", "quantity": 4, "item_name": "Garlic Naan", "order_time": "2026-08-16T08:21:00", "unit_price": 60.0, "customer_id": "C0311", "customer_city": "Mumbai", "customer_name": "Arjun Mehta", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.525451	t
1054	ORDB33F45205B	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDB33F45205B", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-07-23T12:21:00", "unit_price": 150.0, "customer_id": "C0060", "customer_city": "PUNE", "customer_name": "  riya iyer ", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.525761	t
1055	ORDAA048CDEBE	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDAA048CDEBE", "quantity": 1, "item_name": "Idli Sambar", "order_time": "2026-09-21T09:24:00", "unit_price": 80.0, "customer_id": "C0197", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.52606	t
1056	ORDD19F44FE0F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDD19F44FE0F", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-08-10T09:13:00", "unit_price": 250.0, "customer_id": "C0043", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.52638	t
1057	ORD18FF84C7F4	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORD18FF84C7F4", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-07-30T13:58:00", "unit_price": 40.0, "customer_id": "C0041", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.526687	t
1058	ORDC2310D908F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDC2310D908F", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-10-12T12:26:00", "unit_price": 380.0, "customer_id": "C0283", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.526989	t
1059	ORD5FC007E65C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5FC007E65C", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-09-21T09:42:00", "unit_price": 220.0, "customer_id": "C0240", "customer_city": "Mumbai", "customer_name": "Anjali Singh", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.527305	t
1060	ORDB75AF60747	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB75AF60747", "quantity": 4, "item_name": "Butter Chicken", "order_time": "2026-10-01T17:25:00", "unit_price": 320.0, "customer_id": "C0050", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.527609	t
1061	ORDC301D93B84	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC301D93B84", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-09-25T08:57:00", "unit_price": 55.0, "customer_id": "C0231", "customer_city": "Thane", "customer_name": "Aarav Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.527902	t
1062	ORD9430920AB8	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD9430920AB8", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-07-27T16:20:00", "unit_price": 220.0, "customer_id": "C0200", "customer_city": "Pune", "customer_name": "Riya Iyer", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.528222	t
1063	ORDC638620998	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC638620998", "quantity": 2, "item_name": "French Fries", "order_time": "2026-08-18T20:25:00", "unit_price": 90.0, "customer_id": null, "customer_city": "Pune", "customer_name": "Arjun Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.528542	t
1064	ORD2C47D5BDCE	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD2C47D5BDCE", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-08-27T08:42:00", "unit_price": 280.0, "customer_id": "C0047", "customer_city": "Mumbai", "customer_name": "Vikram Nair", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.528836	t
1065	ORDE88878945D	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE88878945D", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-07-21T09:36:00", "unit_price": 150.0, "customer_id": "C0053", "customer_city": "Thane", "customer_name": "Rohan Desai", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.529258	t
1066	ORDF160A7BC40	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDF160A7BC40", "quantity": 4, "item_name": "Veg Biryani", "order_time": "2026-07-28T08:51:00", "unit_price": 220.0, "customer_id": "C0006", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.529554	t
1067	ORD627AAF7EB0	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD627AAF7EB0", "quantity": 4, "item_name": "Manchurian", "order_time": "2026-09-07T22:39:00", "unit_price": 210.0, "customer_id": "C0090", "customer_city": "Mumbai", "customer_name": "Aarav Singh", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.529843	t
1068	ORDBD6F8488A3	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDBD6F8488A3", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-09-15T13:11:00", "unit_price": 220.0, "customer_id": "C0103", "customer_city": "Mumbai", "customer_name": "Priya Khan", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.53014	t
1069	ORD457391CE85	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD457391CE85", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-22T08:58:00", "unit_price": 120.0, "customer_id": "C0023", "customer_city": "Mumbai", "customer_name": "Kabir Mehta", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.530438	t
1070	ORD5F22CCE99E	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5F22CCE99E", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-09-30T20:13:00", "unit_price": 220.0, "customer_id": "C0050", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.530746	t
1071	ORD0333E19AFE	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0333E19AFE", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-08-01T08:19:00", "unit_price": 340.0, "customer_id": "C0380", "customer_city": "Thane", "customer_name": "Pooja Iyer", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.531073	t
1072	ORD6F1F4CDA68	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD6F1F4CDA68", "quantity": 1, "item_name": "Chicken Wrap", "order_time": "2026-07-18T13:29:00", "unit_price": 140.0, "customer_id": "C0203", "customer_city": "Pune", "customer_name": "Sneha Patil", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.531433	t
1073	ORDCD35510D4C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCD35510D4C", "quantity": 4, "item_name": "Paneer Butter Masala", "order_time": "2026-09-15T17:07:00", "unit_price": 250.0, "customer_id": "C0377", "customer_city": "Thane", "customer_name": "Aarav Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.531761	t
1074	ORD8865E16306	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD8865E16306", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-09-04T12:39:00", "unit_price": 220.0, "customer_id": "C0238", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.532059	t
1075	ORD21ED396007	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD21ED396007", "quantity": 4, "item_name": "Veg Biryani", "order_time": "2026-10-11T13:14:00", "unit_price": 220.0, "customer_id": "C0221", "customer_city": "Pune", "customer_name": "Arjun Nair", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.532621	t
1076	ORD4E1D92FE12	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD4E1D92FE12", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-07-23T14:42:00", "unit_price": 220.0, "customer_id": "C0163", "customer_city": "Mumbai", "customer_name": "Pooja Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.533025	t
1077	ORDD06B01CED2	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORDD06B01CED2", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-08-23T20:48:00", "unit_price": 55.0, "customer_id": "C0338", "customer_city": "Thane", "customer_name": "Neha Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.53336	t
1078	ORD73BF55CE5C	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD73BF55CE5C", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-07-22T22:54:00", "unit_price": 150.0, "customer_id": "C0328", "customer_city": "Pune", "customer_name": "Vikram Joshi", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.533675	t
1079	ORD5FD8D759E0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5FD8D759E0", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-09-20T21:38:00", "unit_price": 55.0, "customer_id": "C0253", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.53401	t
1080	ORD7C126DD051	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD7C126DD051", "quantity": 1, "item_name": "Filter Coffee", "order_time": "2026-07-21T21:20:00", "unit_price": 40.0, "customer_id": "C0181", "customer_city": "Pune", "customer_name": "Rohan Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.534331	t
1081	ORD342DB4D90B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD342DB4D90B", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-16T16:57:00", "unit_price": 380.0, "customer_id": "C0067", "customer_city": "Thane", "customer_name": "Anjali Patil", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.534641	t
1082	ORD76F6CFE1B9	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD76F6CFE1B9", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-05T19:12:00", "unit_price": 280.0, "customer_id": "C0233", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.534929	t
1083	ORDE18B9CE49F	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDE18B9CE49F", "quantity": 3, "item_name": "Pasta Alfredo", "order_time": "2026-09-30T17:57:00", "unit_price": 280.0, "customer_id": "C0327", "customer_city": "Mumbai", "customer_name": "Priya Joshi", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.535246	t
1084	ORD4173CC0A30	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD4173CC0A30", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-07-20T08:54:00", "unit_price": 380.0, "customer_id": "C0067", "customer_city": "Thane", "customer_name": "Anjali Patil", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.535541	t
1085	ORD81B31F26F0	{"status": "CANCELLED", "cuisine": "Japanese", "order_id": "ORD81B31F26F0", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-08-15T21:40:00", "unit_price": 380.0, "customer_id": "C0123", "customer_city": "Thane", "customer_name": "Arjun Desai", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.535849	t
1086	ORDE532485C07	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDE532485C07", "quantity": 3, "item_name": "French Fries", "order_time": "2026-08-13T22:31:00", "unit_price": 90.0, "customer_id": "C0261", "customer_city": "Pune", "customer_name": "Rohan Joshi", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.536151	t
1087	ORDDA8BA30CDD	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDDA8BA30CDD", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-10-09T17:21:00", "unit_price": 110.0, "customer_id": "C0393", "customer_city": "Pune", "customer_name": "Priya Joshi", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.536448	t
1088	ORDCFE40CFBB5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCFE40CFBB5", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-08-13T12:12:00", "unit_price": 55.0, "customer_id": "C0117", "customer_city": "Thane", "customer_name": "Pooja Nair", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.536849	t
1089	ORD3747DC5780	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3747DC5780", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-11T16:23:00", "unit_price": 380.0, "customer_id": "C0381", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.537169	t
1090	ORD064D03E271	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD064D03E271", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-08-28T13:34:00", "unit_price": 220.0, "customer_id": "C0233", "customer_city": "Mumbai", "customer_name": "Priya Desai", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.537472	t
1091	ORD1CCEDC6900	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORD1CCEDC6900", "quantity": 1, "item_name": "Masala Dosa", "order_time": "2026-09-30T20:09:00", "unit_price": -110.0, "customer_id": "C0191", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.53778	t
1092	ORDA5B8AC90A7	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDA5B8AC90A7", "quantity": 3, "item_name": "Masala Dosa", "order_time": "2026-07-26T21:04:00", "unit_price": 110.0, "customer_id": "C0068", "customer_city": "Pune", "customer_name": "Neha Patil", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.538095	t
1093	ORD08E2D4FEA2	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD08E2D4FEA2", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-10-04T19:27:00", "unit_price": 340.0, "customer_id": "C0159", "customer_city": "Thane", "customer_name": "Sneha Sharma", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.538392	t
1094	ORDBF2593A134	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDBF2593A134", "quantity": 2, "item_name": "Veg Sushi Roll", "order_time": "2026-09-10T17:26:00", "unit_price": 350.0, "customer_id": "C0228", "customer_city": "Thane", "customer_name": "Neha Iyer", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.538826	t
1095	ORD87581FCD4D	{"status": "CANCELLED", "cuisine": "Fast Food", "order_id": "ORD87581FCD4D", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-13T09:37:00", "unit_price": 150.0, "customer_id": "C0206", "customer_city": "Pune", "customer_name": "Sneha Nair", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.539143	t
1096	ORD3FB33E122C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3FB33E122C", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-07-19T08:57:00", "unit_price": 150.0, "customer_id": "C0245", "customer_city": "Thane", "customer_name": "Aarav Nair", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.539433	t
1097	ORD1701D2F3DB	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD1701D2F3DB", "quantity": 1, "item_name": "Manchurian", "order_time": "2026-08-11T20:05:00", "unit_price": 210.0, "customer_id": "C0031", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.53975	t
1098	ORD87F568F475	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD87F568F475", "quantity": 3, "item_name": "Garlic Bread", "order_time": "2026-09-13T12:49:00", "unit_price": 120.0, "customer_id": "C0024", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.540044	t
1099	ORD6C78907270	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD6C78907270", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-28T20:55:00", "unit_price": 150.0, "customer_id": "C0028", "customer_city": "Thane", "customer_name": "Vikram Kulkarni", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.540338	t
1100	ORD0617C15A37	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD0617C15A37", "quantity": 2, "item_name": "Fried Rice", "order_time": "2026-09-30T13:02:00", "unit_price": 180.0, "customer_id": "C0340", "customer_city": "Mumbai", "customer_name": "Sahil Sharma", "restaurant_id": "R002", "payment_method": "CARD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.540632	t
1101	ORDCE8966B7D2	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCE8966B7D2", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-09-22T09:54:00", "unit_price": 250.0, "customer_id": "C0381", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.540919	t
1102	ORDD06A14BCA6	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDD06A14BCA6", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-07-26T17:20:00", "unit_price": 350.0, "customer_id": "C0377", "customer_city": "Thane", "customer_name": "Aarav Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.541236	t
1103	ORD48EA464224	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORD48EA464224", "quantity": 2, "item_name": "Chicken Biryani", "order_time": "2026-08-16T21:30:00", "unit_price": 280.0, "customer_id": "C0239", "customer_city": "Pune", "customer_name": "Sneha Desai", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.541538	t
1104	ORDCAF6AA03F4	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDCAF6AA03F4", "quantity": 2, "item_name": "Veg Biryani", "order_time": "2026-07-29T13:03:00", "unit_price": 220.0, "customer_id": "C0351", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.542002	t
1105	ORD9968190923	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD9968190923", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-09-23T21:16:00", "unit_price": 250.0, "customer_id": "C0389", "customer_city": "Thane", "customer_name": "Pooja Singh", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.542306	t
1106	ORD144A03498A	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD144A03498A", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-09-24T22:09:00", "unit_price": 190.0, "customer_id": "C0070", "customer_city": "Mumbai", "customer_name": "Kabir Sharma", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.542615	t
1107	ORDC3E651DF57	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC3E651DF57", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-07-24T09:52:00", "unit_price": 140.0, "customer_id": "C0144", "customer_city": "Pune", "customer_name": "Neha Sharma", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.542934	t
1108	ORDB3E1F601C4	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDB3E1F601C4", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-09-13T09:59:00", "unit_price": 350.0, "customer_id": "C0007", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.543263	t
1109	ORD17D740F57C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD17D740F57C", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-07-17T21:45:00", "unit_price": 340.0, "customer_id": "C0196", "customer_city": "Thane", "customer_name": "Vikram Joshi", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.543584	t
1110	ORD4FD5A11565	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD4FD5A11565", "quantity": 4, "item_name": "Idli Sambar", "order_time": "2026-09-14T17:24:00", "unit_price": 80.0, "customer_id": "C0191", "customer_city": "Pune", "customer_name": "Priya Iyer", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.543883	t
1111	ORDADC723C06C	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDADC723C06C", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-09-19T21:25:00", "unit_price": 340.0, "customer_id": "C0314", "customer_city": "Thane", "customer_name": "Priya Desai", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.544177	t
1112	ORDCD0374B1B4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDCD0374B1B4", "quantity": 2, "item_name": "Butter Naan", "order_time": "2026-07-21T20:37:00", "unit_price": 55.0, "customer_id": "C0398", "customer_city": "Thane", "customer_name": "Riya Singh", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.544458	t
1113	ORD538A1EAAA0	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD538A1EAAA0", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-08-06T09:55:00", "unit_price": 40.0, "customer_id": "C0345", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.544784	t
1114	ORDAB8304B080	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAB8304B080", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-07-26T12:55:00", "unit_price": 250.0, "customer_id": "C0173", "customer_city": "Thane", "customer_name": "Anjali Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.545084	t
1115	ORDC5AC4B9C2D	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDC5AC4B9C2D", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-09-01T17:49:00", "unit_price": 80.0, "customer_id": "C0155", "customer_city": "Pune", "customer_name": "Rohan Mehta", "restaurant_id": "R004", "payment_method": "CARD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.54539	t
1116	ORDF6F6D69C13	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF6F6D69C13", "quantity": 4, "item_name": "Veg Sushi Roll", "order_time": "2026-07-28T12:44:00", "unit_price": 350.0, "customer_id": "C0082", "customer_city": "Thane", "customer_name": "Sahil Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.5457	t
1117	ORDAB5872343A	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDAB5872343A", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-27T16:41:00", "unit_price": 380.0, "customer_id": "C0030", "customer_city": "Thane", "customer_name": "Sneha Iyer", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.545989	t
1118	ORDB070A0F2D8	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDB070A0F2D8", "quantity": 1, "item_name": "French Fries", "order_time": "2026-08-09T09:50:00", "unit_price": 90.0, "customer_id": "C0219", "customer_city": "Pune", "customer_name": "Arjun Nair", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.546294	t
1119	ORDF5CC897A78	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDF5CC897A78", "quantity": 0, "item_name": "Paneer Butter Masala", "order_time": "2026-08-24T16:52:00", "unit_price": 250.0, "customer_id": "C0007", "customer_city": "Thane", "customer_name": "Riya Khan", "restaurant_id": "R007", "payment_method": "COD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.546598	t
1120	ORD0DBACF3B4F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0DBACF3B4F", "quantity": 2, "item_name": "Paneer Butter Masala", "order_time": "2026-07-28T08:38:00", "unit_price": 250.0, "customer_id": "C0034", "customer_city": "Thane", "customer_name": "Neha Mehta", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.547003	t
1121	ORD836D71BF99	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD836D71BF99", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-07-26T20:34:00", "unit_price": 140.0, "customer_id": "C0015", "customer_city": "Pune", "customer_name": "Kabir Patil", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.547379	t
1122	ORD914C0706AA	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD914C0706AA", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-09-30T21:37:00", "unit_price": 220.0, "customer_id": "C0033", "customer_city": "Pune", "customer_name": "Sneha Joshi", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.547854	t
1123	ORD1E3F707654	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD1E3F707654", "quantity": 2, "item_name": "French Fries", "order_time": "2026-09-01T13:30:00", "unit_price": 90.0, "customer_id": "C0015", "customer_city": "PUNE", "customer_name": "  kabir patil ", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.548206	t
1124	ORD7E7724B8C6	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD7E7724B8C6", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-09-18T13:54:00", "unit_price": 380.0, "customer_id": "C0333", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.548766	t
1125	ORDBC26E51201	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDBC26E51201", "quantity": 2, "item_name": "Hakka Noodles", "order_time": "2026-08-17T20:28:00", "unit_price": 190.0, "customer_id": "C0327", "customer_city": "MUMBAI", "customer_name": "  priya joshi ", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.549242	t
1126	ORD863E3F3E6C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD863E3F3E6C", "quantity": 2, "item_name": "Manchurian", "order_time": "2026-07-24T13:24:00", "unit_price": 210.0, "customer_id": "C0329", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.549567	t
1127	ORD45F2792144	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD45F2792144", "quantity": 4, "item_name": "Pasta Alfredo", "order_time": "2026-07-20T09:34:00", "unit_price": 280.0, "customer_id": "C0343", "customer_city": "Mumbai", "customer_name": "Rohan Sharma", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.549915	t
1128	ORD432B76EBDB	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD432B76EBDB", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-10-03T20:06:00", "unit_price": 190.0, "customer_id": "C0290", "customer_city": "Mumbai", "customer_name": "Vikram Desai", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.550223	t
1129	ORDF2460383E5	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF2460383E5", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-08-11T20:48:00", "unit_price": 380.0, "customer_id": "C0257", "customer_city": "Thane", "customer_name": "Kabir Singh", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.550519	t
1130	ORD078A3C4F64	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD078A3C4F64", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-07-19T17:03:00", "unit_price": 350.0, "customer_id": "C0341", "customer_city": "Thane", "customer_name": "Kabir Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.550844	t
1131	ORD1F3204FADC	{"status": "CANCELLED", "cuisine": "Hyderabadi", "order_id": "ORD1F3204FADC", "quantity": 3, "item_name": "Raita", "order_time": "2026-09-22T12:41:00", "unit_price": 40.0, "customer_id": "C0297", "customer_city": "Pune", "customer_name": "Sneha Singh", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.551136	t
1132	ORD79BA4AB342	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD79BA4AB342", "quantity": 0, "item_name": "Veg Sushi Roll", "order_time": "2026-08-20T20:13:00", "unit_price": 350.0, "customer_id": "C0377", "customer_city": "Thane", "customer_name": "Aarav Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.551437	t
1133	ORDBE89269A21	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDBE89269A21", "quantity": 4, "item_name": "Raita", "order_time": "2026-09-11T20:03:00", "unit_price": 40.0, "customer_id": "C0345", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.551731	t
1134	ORD7D7C8C1269	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD7D7C8C1269", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-09-01T17:33:00", "unit_price": 280.0, "customer_id": "C0088", "customer_city": "Mumbai", "customer_name": "Neha Singh", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.552037	t
1135	ORD1456E2D791	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD1456E2D791", "quantity": 4, "item_name": "Miso Soup", "order_time": "2026-07-25T19:20:00", "unit_price": 150.0, "customer_id": "C0141", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.552341	t
1136	ORDC5C6905300	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDC5C6905300", "quantity": 2, "item_name": "Chicken Wrap", "order_time": "2026-10-10T13:36:00", "unit_price": 140.0, "customer_id": "C0203", "customer_city": "Pune", "customer_name": "Sneha Patil", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.552649	t
1137	ORDC551C97F8B	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDC551C97F8B", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-10-14T14:56:00", "unit_price": 380.0, "customer_id": "C0044", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.552951	t
1138	ORD35088072A4	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD35088072A4", "quantity": 3, "item_name": "Chicken Wrap", "order_time": "2026-08-03T08:33:00", "unit_price": 140.0, "customer_id": "C0108", "customer_city": "Pune", "customer_name": "Kabir Nair", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.553252	t
1139	ORD40ACD6D0E5	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD40ACD6D0E5", "quantity": 4, "item_name": "Pasta Alfredo", "order_time": "2026-09-10T20:50:00", "unit_price": 280.0, "customer_id": "C0163", "customer_city": "Mumbai", "customer_name": "Pooja Singh", "restaurant_id": "R003", "payment_method": "COD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.553543	t
1140	ORDADEEBC3AA0	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDADEEBC3AA0", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-10-13T20:09:00", "unit_price": 150.0, "customer_id": "C0061", "customer_city": "Thane", "customer_name": "Anjali Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.553834	t
1141	ORDAE2AC1C407	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDAE2AC1C407", "quantity": 1, "item_name": "Fried Rice", "order_time": "2026-08-22T08:01:00", "unit_price": 180.0, "customer_id": "C0009", "customer_city": "Mumbai", "customer_name": "Pooja Singh", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.554133	t
1142	ORDBB8BF37548	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDBB8BF37548", "quantity": 3, "item_name": "Veg Biryani", "order_time": "2026-09-07T12:35:00", "unit_price": 220.0, "customer_id": "C0359", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.55444	t
1143	ORDC0F1CDAE55	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDC0F1CDAE55", "quantity": 2, "item_name": "Pasta Alfredo", "order_time": "2026-07-17T19:02:00", "unit_price": 280.0, "customer_id": "C0017", "customer_city": "Mumbai", "customer_name": "Aarav Sharma", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.554743	t
1144	ORD8E067E2ECE	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD8E067E2ECE", "quantity": 2, "item_name": "Raita", "order_time": "2026-07-29T13:39:00", "unit_price": 40.0, "customer_id": "C0246", "customer_city": "PUNE", "customer_name": "  riya khan ", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.555046	t
1145	ORD4949C34F98	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD4949C34F98", "quantity": 2, "item_name": "Chicken Biryani", "order_time": "2026-08-15T19:22:00", "unit_price": 280.0, "customer_id": "C0300", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.555369	t
1146	ORD424F0D6D88	{"status": "CANCELLED", "cuisine": "North Indian", "order_id": "ORD424F0D6D88", "quantity": 3, "item_name": "Dal Makhani", "order_time": "2026-09-13T14:55:00", "unit_price": 220.0, "customer_id": "C0101", "customer_city": "Mumbai", "customer_name": "Kabir Iyer", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.555675	t
1147	ORD43A2883AA7	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD43A2883AA7", "quantity": 4, "item_name": "French Fries", "order_time": "2026-07-27T20:54:00", "unit_price": 90.0, "customer_id": "C0345", "customer_city": "Pune", "customer_name": "Kabir Iyer", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.555964	t
1148	ORDDA758C4010	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDDA758C4010", "quantity": 1, "item_name": "Tandoori Chicken", "order_time": "2026-07-19T22:16:00", "unit_price": 340.0, "customer_id": "C0390", "customer_city": "Thane", "customer_name": "Vikram Kulkarni", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.556257	t
1149	ORD44AD770DF0	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD44AD770DF0", "quantity": 3, "item_name": "Ramen Bowl", "order_time": "2026-07-20T16:23:00", "unit_price": 380.0, "customer_id": "C0096", "customer_city": "THANE", "customer_name": "  sneha patil ", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.556558	t
1150	ORD932AE32DA6	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD932AE32DA6", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-08-11T21:21:00", "unit_price": 380.0, "customer_id": "C0095", "customer_city": "Thane", "customer_name": "Riya Nair", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.556857	t
1151	ORD445717478C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD445717478C", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-08-20T19:49:00", "unit_price": 150.0, "customer_id": "C0348", "customer_city": "Thane", "customer_name": "Rohan Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.557276	t
1152	ORD0F1ACC6752	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD0F1ACC6752", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-09-26T21:20:00", "unit_price": 220.0, "customer_id": "C0162", "customer_city": "Mumbai", "customer_name": "Vikram Sharma", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.557569	t
1153	ORDB32240BC22	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORDB32240BC22", "quantity": 1, "item_name": "Pasta Alfredo", "order_time": "2026-09-26T16:37:00", "unit_price": 280.0, "customer_id": "C0157", "customer_city": "Mumbai", "customer_name": "Rohan Khan", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.55787	t
1154	ORD42BE8DC97F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD42BE8DC97F", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-29T19:18:00", "unit_price": 350.0, "customer_id": "C0325", "customer_city": "Thane", "customer_name": "Arjun Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.558185	t
1155	ORDAE5EC651D5	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDAE5EC651D5", "quantity": 4, "item_name": "Butter Naan", "order_time": "2026-09-26T20:32:00", "unit_price": 55.0, "customer_id": "C0213", "customer_city": "Thane", "customer_name": "Rohan Desai", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.558478	t
1156	ORDC2A737A55C	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDC2A737A55C", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-08-31T21:20:00", "unit_price": 190.0, "customer_id": "C0329", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.558789	t
1157	ORDF57A7E9757	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF57A7E9757", "quantity": 3, "item_name": "Miso Soup", "order_time": "2026-10-05T08:59:00", "unit_price": 150.0, "customer_id": "C0139", "customer_city": "Thane", "customer_name": "Priya Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.559084	t
1158	ORDB55EC1765A	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDB55EC1765A", "quantity": 1, "item_name": "Hakka Noodles", "order_time": "2026-09-29T14:21:00", "unit_price": 190.0, "customer_id": "C0104", "customer_city": "Mumbai", "customer_name": "Vikram Iyer", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.559363	t
1159	ORD56971B824E	{"status": "DELIVERED", "cuisine": "Italian", "order_id": "ORD56971B824E", "quantity": 4, "item_name": "Pasta Alfredo", "order_time": "2026-07-25T21:49:00", "unit_price": 280.0, "customer_id": "C0024", "customer_city": "Mumbai", "customer_name": "Sneha Nair", "restaurant_id": "R003", "payment_method": "CARD", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.559687	t
1160	ORD70D403E095	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD70D403E095", "quantity": 2, "item_name": "Garlic Naan", "order_time": "2026-09-24T14:18:00", "unit_price": 60.0, "customer_id": "C0365", "customer_city": "Mumbai", "customer_name": "Rohan Singh", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.559992	t
1161	ORDDDD62AF8A5	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDDDD62AF8A5", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-10T20:56:00", "unit_price": 150.0, "customer_id": "C0075", "customer_city": "Pune", "customer_name": "Neha Joshi", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.560301	t
1162	ORD14272B4904	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD14272B4904", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-07-31T16:28:00", "unit_price": 60.0, "customer_id": "C0288", "customer_city": "Mumbai", "customer_name": "Anjali Nair", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.5606	t
1163	ORDD14A8303AA	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORDD14A8303AA", "quantity": 4, "item_name": "Hakka Noodles", "order_time": "2026-09-18T21:06:00", "unit_price": 190.0, "customer_id": "C0329", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R002", "payment_method": "UPI", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.560906	t
1164	ORDC150F5108F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC150F5108F", "quantity": 3, "item_name": "Paneer Butter Masala", "order_time": "2026-08-16T21:44:00", "unit_price": 250.0, "customer_id": "C0190", "customer_city": "Thane", "customer_name": "Rohan Singh", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.561206	t
1165	ORD3A5BC1B066	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD3A5BC1B066", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-08-28T13:16:00", "unit_price": 340.0, "customer_id": "C0121", "customer_city": "Thane", "customer_name": "Arjun Joshi", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.561516	t
1166	ORD1C9F2846A0	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD1C9F2846A0", "quantity": 4, "item_name": "Raita", "order_time": "2026-10-11T13:09:00", "unit_price": 40.0, "customer_id": "C0072", "customer_city": "PUNE", "customer_name": "  arjun desai ", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.56182	t
1167	ORDF595EC4781	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF595EC4781", "quantity": 3, "item_name": "Veg Sushi Roll", "order_time": "2026-09-29T17:17:00", "unit_price": 350.0, "customer_id": "C0381", "customer_city": "Thane", "customer_name": "Sahil Khan", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.562104	t
1168	ORD00B8D6B3D0	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD00B8D6B3D0", "quantity": 1, "item_name": "Paneer Butter Masala", "order_time": "2026-07-29T21:00:00", "unit_price": 250.0, "customer_id": "C0151", "customer_city": "Thane", "customer_name": "Pooja Sharma", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.562405	t
1169	ORDC25246D6F5	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDC25246D6F5", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-07-17T13:59:00", "unit_price": 150.0, "customer_id": "C0165", "customer_city": "Thane", "customer_name": "Sneha Desai", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.562707	t
1170	ORDF3084B480F	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDF3084B480F", "quantity": 2, "item_name": "Filter Coffee", "order_time": "2026-09-19T12:07:00", "unit_price": 40.0, "customer_id": "C0318", "customer_city": "Pune", "customer_name": "Vikram Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.563013	t
1171	ORDF70BACC96F	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDF70BACC96F", "quantity": 1, "item_name": "Veg Sushi Roll", "order_time": "2026-08-15T13:28:00", "unit_price": 350.0, "customer_id": "C0087", "customer_city": "Thane", "customer_name": "Rohan Kulkarni", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.563321	t
1172	ORD2845D7D041	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD2845D7D041", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-07-18T20:43:00", "unit_price": 340.0, "customer_id": "C0159", "customer_city": "Thane", "customer_name": "Sneha Sharma", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.563657	t
1173	ORD51E210756C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD51E210756C", "quantity": 1, "item_name": "Miso Soup", "order_time": "2026-09-23T16:11:00", "unit_price": 150.0, "customer_id": "C0114", "customer_city": "Thane", "customer_name": "Kabir Kulkarni", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.564008	t
1174	ORD05D1E87830	{"status": "CANCELLED", "cuisine": "South Indian", "order_id": "ORD05D1E87830", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-08-04T16:36:00", "unit_price": 40.0, "customer_id": "C0076", "customer_city": "Pune", "customer_name": "Sahil Kulkarni", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.56433	t
1175	ORD7CEC14E786	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORD7CEC14E786", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-09-28T13:27:00", "unit_price": 60.0, "customer_id": "C0225", "customer_city": "Mumbai", "customer_name": "Priya Patil", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.56463	t
1176	ORD546F4444F4	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD546F4444F4", "quantity": 1, "item_name": "Garlic Naan", "order_time": "2026-08-30T08:58:00", "unit_price": 60.0, "customer_id": "C0384", "customer_city": "Mumbai", "customer_name": "Vikram Patil", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.564965	t
1177	ORD51D3010139	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD51D3010139", "quantity": 3, "item_name": "Butter Naan", "order_time": "2026-09-11T20:39:00", "unit_price": 55.0, "customer_id": "C0347", "customer_city": "Thane", "customer_name": "Priya Joshi", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.565263	t
1178	ORDEBCE1D5636	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDEBCE1D5636", "quantity": 2, "item_name": "Paneer Tikka", "order_time": "2026-08-30T13:06:00", "unit_price": 260.0, "customer_id": "C0017", "customer_city": "MUMBAI", "customer_name": "  aarav sharma ", "restaurant_id": "R001", "payment_method": "UPI", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.565728	t
1179	ORD0BC45636A6	{"status": "DELIVERED", "cuisine": "Chinese", "order_id": "ORD0BC45636A6", "quantity": 4, "item_name": "Fried Rice", "order_time": "2026-08-04T21:30:00", "unit_price": 180.0, "customer_id": "C0174", "customer_city": "Mumbai", "customer_name": "Riya Kulkarni", "restaurant_id": "R002", "payment_method": "COD", "restaurant_name": "Dragon Wok"}	2026-10-14 12:58:52.566173	t
1180	ORD3A9EE497CD	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD3A9EE497CD", "quantity": 1, "item_name": "Ramen Bowl", "order_time": "2026-08-16T09:23:00", "unit_price": 380.0, "customer_id": "C0082", "customer_city": "Thane", "customer_name": "Sahil Desai", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.566799	t
1181	ORDB5D98DA23A	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDB5D98DA23A", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-10-07T20:00:00", "unit_price": 340.0, "customer_id": "C0267", "customer_city": "Thane", "customer_name": "Aarav Khan", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.567118	t
1182	ORDFDD1CC0671	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDFDD1CC0671", "quantity": 1, "item_name": "Paneer Tikka", "order_time": "2026-09-29T08:16:00", "unit_price": 260.0, "customer_id": "C0058", "customer_city": "Mumbai", "customer_name": "Vikram Patil", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.567415	t
1183	ORD14DF53ACD7	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORD14DF53ACD7", "quantity": 4, "item_name": "Cheese Burger", "order_time": "2026-09-26T20:28:00", "unit_price": 150.0, "customer_id": "C0150", "customer_city": "Pune", "customer_name": "Kabir Mehta", "restaurant_id": "R006", "payment_method": "CARD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.567724	t
1184	ORD203988B3AF	{"status": "PLACED", "cuisine": "North Indian", "order_id": "ORD203988B3AF", "quantity": 3, "item_name": "Garlic Naan", "order_time": "2026-07-26T14:36:00", "unit_price": 60.0, "customer_id": "C0021", "customer_city": "Mumbai", "customer_name": "Sahil Singh", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.568018	t
1185	ORD98D68FBE2B	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD98D68FBE2B", "quantity": 4, "item_name": "Chicken Biryani", "order_time": "2026-09-20T21:23:00", "unit_price": 280.0, "customer_id": "C0200", "customer_city": "PUNE", "customer_name": "  riya iyer ", "restaurant_id": "R005", "payment_method": "UPI", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.568302	t
1186	ORDE13F0A7FB3	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDE13F0A7FB3", "quantity": 3, "item_name": "Idli Sambar", "order_time": "2026-09-28T20:52:00", "unit_price": 80.0, "customer_id": "C0004", "customer_city": "Pune", "customer_name": "Priya Sharma", "restaurant_id": "R004", "payment_method": "COD", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.568637	t
1187	ORD5F9FC1C51F	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD5F9FC1C51F", "quantity": 3, "item_name": "Tandoori Chicken", "order_time": "2026-10-06T14:01:00", "unit_price": 340.0, "customer_id": "C0154", "customer_city": "Thane", "customer_name": "Rohan Khan", "restaurant_id": "R007", "payment_method": "CARD", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.568942	t
1188	ORDC9A5695A67	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDC9A5695A67", "quantity": 2, "item_name": "Miso Soup", "order_time": "2026-09-02T19:16:00", "unit_price": 150.0, "customer_id": "C0366", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R008", "payment_method": "UPI", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.569232	t
1189	ORD982F84CC06	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORD982F84CC06", "quantity": 2, "item_name": "Masala Dosa", "order_time": "2026-07-19T20:10:00", "unit_price": 110.0, "customer_id": "C0376", "customer_city": "Pune", "customer_name": "Arjun Sharma", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.569527	t
1190	ORDEC011B5D7B	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDEC011B5D7B", "quantity": 4, "item_name": "Veg Biryani", "order_time": "2026-08-28T13:23:00", "unit_price": 220.0, "customer_id": "C0015", "customer_city": "Pune", "customer_name": "Kabir Patil", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.569839	t
1191	ORDC363BA9101	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC363BA9101", "quantity": 4, "item_name": "Tandoori Chicken", "order_time": "2026-08-04T21:50:00", "unit_price": 340.0, "customer_id": "C0043", "customer_city": "Thane", "customer_name": "Sahil Iyer", "restaurant_id": "R007", "payment_method": "UPI", "restaurant_name": "Tandoori Nights"}	2026-10-14 12:58:52.570143	t
1192	ORDD0F5700B9D	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDD0F5700B9D", "quantity": 3, "item_name": "Cheese Burger", "order_time": "2026-08-21T14:41:00", "unit_price": 150.0, "customer_id": "C0227", "customer_city": "Pune", "customer_name": "Priya Kulkarni", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.570451	t
1193	ORD20AD293574	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORD20AD293574", "quantity": 4, "item_name": "Dal Makhani", "order_time": "2026-09-13T13:31:00", "unit_price": 220.0, "customer_id": "C0329", "customer_city": "Mumbai", "customer_name": "Kabir Kulkarni", "restaurant_id": "R001", "payment_method": "COD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.570749	t
1194	ORDC5C7F04D59	{"status": "DELIVERED", "cuisine": "North Indian", "order_id": "ORDC5C7F04D59", "quantity": 2, "item_name": "Dal Makhani", "order_time": "2026-09-22T16:52:00", "unit_price": -220.0, "customer_id": "C0162", "customer_city": "Mumbai", "customer_name": "Vikram Sharma", "restaurant_id": "R001", "payment_method": "CARD", "restaurant_name": "Spice Garden"}	2026-10-14 12:58:52.571053	t
1195	ORDCF29E33AEC	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDCF29E33AEC", "quantity": 4, "item_name": "Chicken Wrap", "order_time": "2026-10-05T21:55:00", "unit_price": 140.0, "customer_id": "C0197", "customer_city": "Pune", "customer_name": "Sahil Singh", "restaurant_id": "R006", "payment_method": "COD", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.571343	t
1196	ORDE04F2D4F26	{"status": "CANCELLED", "cuisine": "Italian", "order_id": "ORDE04F2D4F26", "quantity": 4, "item_name": "Garlic Bread", "order_time": "2026-08-05T13:49:00", "unit_price": 120.0, "customer_id": "C0085", "customer_city": "Mumbai", "customer_name": "Sneha Kulkarni", "restaurant_id": "R003", "payment_method": "UPI", "restaurant_name": "Pizza Palace"}	2026-10-14 12:58:52.57164	t
1197	ORDF4EA106D7B	{"status": "DELIVERED", "cuisine": "South Indian", "order_id": "ORDF4EA106D7B", "quantity": 4, "item_name": "Filter Coffee", "order_time": "2026-09-19T13:56:00", "unit_price": 40.0, "customer_id": "C0015", "customer_city": "Pune", "customer_name": "Kabir Patil", "restaurant_id": "R004", "payment_method": "UPI", "restaurant_name": "Dosa Corner"}	2026-10-14 12:58:52.571935	t
1198	ORDB884A3A6DE	{"status": "DELIVERED", "cuisine": "Fast Food", "order_id": "ORDB884A3A6DE", "quantity": 3, "item_name": "French Fries", "order_time": "2026-10-03T20:47:00", "unit_price": 90.0, "customer_id": "C0306", "customer_city": "Pune", "customer_name": "Riya Joshi", "restaurant_id": "R006", "payment_method": "UPI", "restaurant_name": "Burger Barn"}	2026-10-14 12:58:52.57223	t
1199	ORD68878296FC	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD68878296FC", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-19T17:06:00", "unit_price": 220.0, "customer_id": "C0068", "customer_city": "Pune", "customer_name": "Neha Patil", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.572537	t
1200	ORD1F335C443C	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORD1F335C443C", "quantity": 2, "item_name": "Ramen Bowl", "order_time": "2026-10-13T20:04:00", "unit_price": 380.0, "customer_id": "C0187", "customer_city": "THANE", "customer_name": "  arjun kulkarni ", "restaurant_id": "R008", "payment_method": "CARD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.572822	t
1201	ORDCE4FC087BC	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORDCE4FC087BC", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-09-29T14:18:00", "unit_price": 220.0, "customer_id": "C0300", "customer_city": "Pune", "customer_name": "Sahil Sharma", "restaurant_id": "R005", "payment_method": "COD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.573114	t
1202	ORDE5EBE21567	{"status": "DELIVERED", "cuisine": "Japanese", "order_id": "ORDE5EBE21567", "quantity": 4, "item_name": "Ramen Bowl", "order_time": "2026-10-05T20:46:00", "unit_price": 380.0, "customer_id": "C0205", "customer_city": "Thane", "customer_name": "Pooja Nair", "restaurant_id": "R008", "payment_method": "COD", "restaurant_name": "Sushi Zen"}	2026-10-14 12:58:52.573552	t
1203	ORD5A8D235264	{"status": "DELIVERED", "cuisine": "Hyderabadi", "order_id": "ORD5A8D235264", "quantity": 1, "item_name": "Veg Biryani", "order_time": "2026-07-26T08:16:00", "unit_price": 220.0, "customer_id": "C0060", "customer_city": "Pune", "customer_name": "Riya Iyer", "restaurant_id": "R005", "payment_method": "CARD", "restaurant_name": "Biryani House"}	2026-10-14 12:58:52.573847	t
\.


--
-- Name: dim_customer_customer_key_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dim_customer_customer_key_seq', 1129, true);


--
-- Name: dim_restaurant_restaurant_key_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.dim_restaurant_restaurant_key_seq', 1129, true);


--
-- Name: rejected_orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.rejected_orders_id_seq', 74, true);


--
-- Name: stg_orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.stg_orders_id_seq', 1204, true);


--
-- Name: dim_customer dim_customer_customer_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_customer
    ADD CONSTRAINT dim_customer_customer_id_key UNIQUE (customer_id);


--
-- Name: dim_customer dim_customer_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_customer
    ADD CONSTRAINT dim_customer_pkey PRIMARY KEY (customer_key);


--
-- Name: dim_restaurant dim_restaurant_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_restaurant
    ADD CONSTRAINT dim_restaurant_pkey PRIMARY KEY (restaurant_key);


--
-- Name: dim_restaurant dim_restaurant_restaurant_id_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_restaurant
    ADD CONSTRAINT dim_restaurant_restaurant_id_key UNIQUE (restaurant_id);


--
-- Name: dim_time dim_time_full_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_time
    ADD CONSTRAINT dim_time_full_date_key UNIQUE (full_date);


--
-- Name: dim_time dim_time_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.dim_time
    ADD CONSTRAINT dim_time_pkey PRIMARY KEY (time_key);


--
-- Name: fact_orders fact_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_orders
    ADD CONSTRAINT fact_orders_pkey PRIMARY KEY (order_id);


--
-- Name: rejected_orders rejected_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.rejected_orders
    ADD CONSTRAINT rejected_orders_pkey PRIMARY KEY (id);


--
-- Name: stg_orders stg_orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.stg_orders
    ADD CONSTRAINT stg_orders_pkey PRIMARY KEY (id);


--
-- Name: idx_fact_customer; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fact_customer ON public.fact_orders USING btree (customer_key);


--
-- Name: idx_fact_rest; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fact_rest ON public.fact_orders USING btree (restaurant_key);


--
-- Name: idx_fact_time; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fact_time ON public.fact_orders USING btree (time_key);


--
-- Name: fact_orders fact_orders_customer_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_orders
    ADD CONSTRAINT fact_orders_customer_key_fkey FOREIGN KEY (customer_key) REFERENCES public.dim_customer(customer_key);


--
-- Name: fact_orders fact_orders_restaurant_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_orders
    ADD CONSTRAINT fact_orders_restaurant_key_fkey FOREIGN KEY (restaurant_key) REFERENCES public.dim_restaurant(restaurant_key);


--
-- Name: fact_orders fact_orders_time_key_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.fact_orders
    ADD CONSTRAINT fact_orders_time_key_fkey FOREIGN KEY (time_key) REFERENCES public.dim_time(time_key);


--
-- PostgreSQL database dump complete
--

\unrestrict ut4OYg5ksihPE74gUZ4DwVQTTaUYqaIxpbLN3iiXi4uNBp0lisJNZ3Jw5dHBCG5

