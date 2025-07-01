--
-- PostgreSQL database dump
--

-- Dumped from database version 12.22 (Ubuntu 12.22-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.22 (Ubuntu 12.22-0ubuntu0.20.04.1)

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

--
-- Name: generate_message_number(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_message_number() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    last_number INTEGER;
BEGIN
    -- Получаем последний номер сообщения для данной заявки
    SELECT COALESCE(MAX(message_number), 0) INTO last_number
    FROM ticket_messages
    WHERE ticket_id = NEW.ticket_id;
    
    -- Увеличиваем номер на 1
    NEW.message_number = last_number + 1;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.generate_message_number() OWNER TO postgres;

--
-- Name: generate_ticket_number(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_ticket_number() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
DECLARE
    generated_number VARCHAR(20); -- Переменная для сгенерированного номера
    timestamp_part VARCHAR(14);
    random_part VARCHAR(6);
    exists_count INTEGER;
BEGIN
    LOOP -- Начинаем цикл для генерации и проверки
        timestamp_part := to_char(CURRENT_TIMESTAMP, 'YYYYMMDDHH24MISS');
        random_part := lpad(floor(random() * 1000000)::text, 6, '0');
        generated_number := timestamp_part || random_part; -- Присваиваем значение локальной переменной

        -- Проверяем, что такого номера еще нет, используя локальную переменную
        SELECT COUNT(*) INTO exists_count
        FROM tickets t -- Используем алиас t для таблицы tickets
        WHERE t.ticket_number = generated_number; -- Сравниваем с локальной переменной

        IF exists_count = 0 THEN
            EXIT; -- Если номер уникален, выходим из цикла
        END IF;
        -- Если номер не уникален, цикл начнется заново и сгенерирует новый номер
    END LOOP;

    RETURN generated_number; -- Возвращаем уникальный сгенерированный номер
END;
$$;


ALTER FUNCTION public.generate_ticket_number() OWNER TO postgres;

--
-- Name: handle_ticket_closure(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_ticket_closure() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    closed_status_id INTEGER;
BEGIN
    -- Получаем ID статуса 'closed'
    SELECT id INTO closed_status_id FROM ticket_statuses WHERE name = 'closed';
    
    -- Если статус изменился на 'closed', устанавливаем closed_at
    IF NEW.status_id = closed_status_id AND 
       (OLD.status_id != NEW.status_id OR OLD.status_id IS NULL) THEN
        NEW.closed_at = CURRENT_TIMESTAMP;
    -- Если статус изменился с 'closed' на другой, сбрасываем closed_at
    ELSIF OLD.status_id = closed_status_id AND 
          NEW.status_id != OLD.status_id THEN
        NEW.closed_at = NULL;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.handle_ticket_closure() OWNER TO postgres;

--
-- Name: set_initial_closed_at(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_initial_closed_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    closed_status_id INTEGER;
BEGIN
    -- Получаем ID статуса 'closed'
    SELECT id INTO closed_status_id FROM ticket_statuses WHERE name = 'closed';
    
    -- Если статус 'closed', устанавливаем closed_at
    IF NEW.status_id = closed_status_id THEN
        NEW.closed_at = CURRENT_TIMESTAMP;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_initial_closed_at() OWNER TO postgres;

--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: clients; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.clients (
    clients_id integer NOT NULL,
    email character varying(128) NOT NULL,
    fio character varying(128) NOT NULL,
    password character varying(255),
    "position" character varying(80) NOT NULL,
    company character varying(128) NOT NULL,
    activity character varying(128) NOT NULL,
    city character varying(80) NOT NULL,
    phone character varying(11)
);


ALTER TABLE public.clients OWNER TO postgres;

--
-- Name: clients_clients_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.clients_clients_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.clients_clients_id_seq OWNER TO postgres;

--
-- Name: clients_clients_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.clients_clients_id_seq OWNED BY public.clients.clients_id;


--
-- Name: documents; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.documents (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    file_path character varying(255) NOT NULL,
    file_size integer,
    file_type character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.documents OWNER TO postgres;

--
-- Name: documents_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.documents_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.documents_id_seq OWNER TO postgres;

--
-- Name: documents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.documents_id_seq OWNED BY public.documents.id;


--
-- Name: emails; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.emails (
    id integer NOT NULL,
    thread_id character varying(255) NOT NULL,
    subject character varying(255) NOT NULL,
    body text NOT NULL,
    from_email character varying(255) NOT NULL,
    is_outgoing boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_closed boolean DEFAULT false,
    user_id integer,
    to_email character varying(255)
);


ALTER TABLE public.emails OWNER TO postgres;

--
-- Name: emails_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.emails_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.emails_id_seq OWNER TO postgres;

--
-- Name: emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.emails_id_seq OWNED BY public.emails.id;


--
-- Name: ticket_attachments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ticket_attachments (
    id integer NOT NULL,
    message_id integer NOT NULL,
    file_name character varying(255) NOT NULL,
    file_path character varying(255) NOT NULL,
    file_size integer NOT NULL,
    mime_type character varying(100) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.ticket_attachments OWNER TO postgres;

--
-- Name: ticket_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ticket_attachments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ticket_attachments_id_seq OWNER TO postgres;

--
-- Name: ticket_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ticket_attachments_id_seq OWNED BY public.ticket_attachments.id;


--
-- Name: ticket_messages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ticket_messages (
    id integer NOT NULL,
    ticket_id integer NOT NULL,
    message_number integer NOT NULL,
    sender_type character varying(20) NOT NULL,
    sender_id integer,
    sender_email character varying(255) NOT NULL,
    message text NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    is_read boolean DEFAULT false,
    email_message_id character varying(255),
    in_reply_to character varying(255),
    email_id integer
);


ALTER TABLE public.ticket_messages OWNER TO postgres;

--
-- Name: ticket_messages_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ticket_messages_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ticket_messages_id_seq OWNER TO postgres;

--
-- Name: ticket_messages_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ticket_messages_id_seq OWNED BY public.ticket_messages.id;


--
-- Name: ticket_statuses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ticket_statuses (
    id integer NOT NULL,
    name character varying(50) NOT NULL,
    description text
);


ALTER TABLE public.ticket_statuses OWNER TO postgres;

--
-- Name: ticket_statuses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ticket_statuses_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.ticket_statuses_id_seq OWNER TO postgres;

--
-- Name: ticket_statuses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ticket_statuses_id_seq OWNED BY public.ticket_statuses.id;


--
-- Name: tickets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tickets (
    id integer NOT NULL,
    ticket_number character varying(20) NOT NULL,
    user_id integer NOT NULL,
    subject character varying(255) NOT NULL,
    status_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    closed_at timestamp with time zone,
    email_thread_id character varying(255)
);


ALTER TABLE public.tickets OWNER TO postgres;

--
-- Name: tickets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tickets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.tickets_id_seq OWNER TO postgres;

--
-- Name: tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tickets_id_seq OWNED BY public.tickets.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(255) NOT NULL,
    fio character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    "position" character varying(255) NOT NULL,
    company character varying(255) NOT NULL,
    activity_sphere character varying(255) NOT NULL,
    city character varying(255) NOT NULL,
    phone character varying(50) NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    account_status character varying(50) DEFAULT 'pending_approval'::character varying NOT NULL
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: videos; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.videos (
    id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    file_path character varying(255) NOT NULL,
    file_size integer NOT NULL,
    thumbnail_path character varying(255),
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.videos OWNER TO postgres;

--
-- Name: videos_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.videos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.videos_id_seq OWNER TO postgres;

--
-- Name: videos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.videos_id_seq OWNED BY public.videos.id;


--
-- Name: clients clients_id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients ALTER COLUMN clients_id SET DEFAULT nextval('public.clients_clients_id_seq'::regclass);


--
-- Name: documents id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documents ALTER COLUMN id SET DEFAULT nextval('public.documents_id_seq'::regclass);


--
-- Name: emails id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emails ALTER COLUMN id SET DEFAULT nextval('public.emails_id_seq'::regclass);


--
-- Name: ticket_attachments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_attachments ALTER COLUMN id SET DEFAULT nextval('public.ticket_attachments_id_seq'::regclass);


--
-- Name: ticket_messages id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_messages ALTER COLUMN id SET DEFAULT nextval('public.ticket_messages_id_seq'::regclass);


--
-- Name: ticket_statuses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_statuses ALTER COLUMN id SET DEFAULT nextval('public.ticket_statuses_id_seq'::regclass);


--
-- Name: tickets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets ALTER COLUMN id SET DEFAULT nextval('public.tickets_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: videos id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.videos ALTER COLUMN id SET DEFAULT nextval('public.videos_id_seq'::regclass);


--
-- Data for Name: clients; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.clients (clients_id, email, fio, password, "position", company, activity, city, phone) FROM stdin;
1	test.user1@example.com	Тестов Тест Тестович	\N	Тестировщик	ООО Тест Инк.	IT / Тестирование	Тестбург	+7900123
\.


--
-- Data for Name: documents; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.documents (id, title, file_path, file_size, file_type, created_at, updated_at) FROM stdin;
1	отправка документа 	uploads\\documents\\document-1745985196859-319973081.docx	52534	docx	2025-04-30 06:53:17.098041+03	2025-04-30 06:53:17.098041+03
2	отправка документа 	uploads\\documents\\document-1745985929869-30028086.docx	52534	docx	2025-04-30 07:05:29.877634+03	2025-04-30 07:05:29.877634+03
3	отправка документа 	uploads\\documents\\document-1745986016763-853219239.pdf	688525	pdf	2025-04-30 07:06:56.816395+03	2025-04-30 07:06:56.816395+03
\.


--
-- Data for Name: emails; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.emails (id, thread_id, subject, body, from_email, is_outgoing, created_at, is_closed, user_id, to_email) FROM stdin;
1	ticket-20250507103220030664-1746588740796	Re: tew [ticket-20250507103220030664-1746588740796]	dfgh	qwe@qwe.ru	f	2025-05-07 06:58:46.268698+03	f	11	\N
2	ticket-20250507103220030664-1746588740796	Re: Проблема с доступом [ticket-20250507103220030664-1746588740796]	Я проверил настройки, которые вы прислали, но проблема осталась. Можете посмотреть логи?	user@example.com	f	2025-05-07 07:04:22.554324+03	f	11	\N
3	ticket-20250507103220030664-1746588740796	Re: tew [ticket-20250507103220030664-1746588740796]	вап	qwe@qwe.ru	f	2025-05-07 07:10:10.829842+03	f	11	\N
4	ticket-20250507103220030664-1746588740796	Re: Проблема с доступом [ticket-20250507103220030664-1746588740796]	Ответ	user@example.com	f	2025-05-07 07:10:31.374398+03	f	11	\N
5	ticket-20250507103220030664-1746588740796	Re: Проблема с доступом [ticket-20250507103220030664-1746588740796]	Ответ2	user@example.com	f	2025-05-07 07:21:49.31092+03	f	\N	\N
6	ticket-20250507103220030664-1746588740796	Re: tew [ticket-20250507103220030664-1746588740796]	erty	qwe@qwe.ru	f	2025-05-07 07:21:59.654697+03	f	11	\N
7	ticket-20250507103220030664-1746588740796	Re: Проблема с доступом [ticket-20250507103220030664-1746588740796]	Ответ3	user@example.com	f	2025-05-07 07:22:18.295887+03	f	\N	\N
8	ticket-20250507112527823603-1746591927814	Re: Проблема с доступом [ticket-20250507112527823603-1746591927814]	Что означает Ваше число?	user@example.com	f	2025-05-07 07:32:32.473164+03	f	\N	\N
9	ticket-20250507115932294093-1746593973012	Re: ИСХОДНАЯ_ТЕМА_ЗАЯВКИ [Ticket#20250507115932294093]	Здравствуйте, это мой ответ на ваше предыдущее сообщение.\n\nПроблема все еще актуальна. Я перезагрузил компьютер, но это не помогло.\n\nС уважением,\nИван	qwe@qwe.ru	f	2025-05-07 08:02:18.420928+03	f	11	\N
10	ticket-20250507115932294093-1746593973012	Re: ИСХОДНАЯ_ТЕМА_ЗАЯВКИ [Ticket#20250507115932294093]	Здравствуйте, это мой ответ на ваше предыдущее сообщение.\n\nПроблема все еще актуальна. Я перезагрузил компьютер, но это не помогло.\n\nС уважением,\nИван	qwe@qwe.ru	f	2025-05-07 08:04:04.988246+03	f	11	\N
11	ticket-20250513060213184409-1747105333078	Новая заявка #20250513060213184409: 13.05(2)	Пользователь: undefined (qwe@qwe.ru)\nТема: 13.05(2)\nСообщение:\n13.05(2)\n---\nИдентификатор заявки: 20250513060213184409\nИдентификатор треда (для ответов): ticket-20250513060213184409-1747105333078	devsanya.ru	t	2025-05-13 06:02:13.242147+03	f	11	\N
12	ticket-20250513072005451354-1747110005999	Новая заявка #20250513072005451354: 13.05(3)	Пользователь: undefined (qwe@qwe.ru)\nТема: 13.05(3)\nСообщение:\n13.05(3)\n---\nИдентификатор заявки: 20250513072005451354\nИдентификатор треда (для ответов): ticket-20250513072005451354-1747110005999	devsanya.ru	t	2025-05-13 07:20:06.192715+03	f	11	\N
13	ticket-20250513102523318195-1747121123024	Новая заявка #20250513102523318195: Тема13.05(4)	Пользователь: undefined (qwe@qwe.ru)\nТема: Тема13.05(4)\nСообщение:\nСообщение 13.05(4)\n---\nИдентификатор заявки: 20250513102523318195\nИдентификатор треда (для ответов): ticket-20250513102523318195-1747121123024	devsanya.ru	t	2025-05-13 10:25:23.187026+03	f	11	\N
14	ticket-20250514042623782792-1747185983051	Новая заявка #20250514042623782792: 14.05	Пользователь: undefined (qwe@qwe.ru)\nТема: 14.05\nСообщение:\n14.05 новая тех.заявка\n---\nИдентификатор заявки: 20250514042623782792\nИдентификатор треда (для ответов): ticket-20250514042623782792-1747185983051	devsanya.ru	t	2025-05-14 04:26:23.258533+03	f	11	\N
15	ticket-20250514060623249172-1747191983067	Новая заявка #20250514060623249172: 14.05 с файлами	Пользователь: undefined (qwe@qwe.ru)\nТема: 14.05 с файлами\nСообщение:\nотправка заявки с файлами\n---\nИдентификатор заявки: 20250514060623249172\nИдентификатор треда (для ответов): ticket-20250514060623249172-1747191983067	devsanya.ru	t	2025-05-14 06:06:23.286908+03	f	11	\N
16	ticket-20250514060801054493-1747192081334	Новая заявка #20250514060801054493: 2345	Пользователь: undefined (qwe@qwe.ru)\nТема: 2345\nСообщение:\n2345\n---\nИдентификатор заявки: 20250514060801054493\nИдентификатор треда (для ответов): ticket-20250514060801054493-1747192081334	devsanya.ru	t	2025-05-14 06:08:01.487645+03	f	11	\N
17	ticket-20250514060815220738-1747192095924	Новая заявка #20250514060815220738: 3456	Пользователь: undefined (qwe@qwe.ru)\nТема: 3456\nСообщение:\n3456\n---\nИдентификатор заявки: 20250514060815220738\nИдентификатор треда (для ответов): ticket-20250514060815220738-1747192095924	devsanya.ru	t	2025-05-14 06:08:16.013193+03	f	11	\N
18	ticket-20250514061644723995-1747192604088	Новая заявка #20250514061644723995: н	Пользователь: undefined (qwe@qwe.ru)\nТема: н\nСообщение:\nн\n---\nИдентификатор заявки: 20250514061644723995\nИдентификатор треда (для ответов): ticket-20250514061644723995-1747192604088	devsanya.ru	t	2025-05-14 06:16:44.262295+03	f	11	\N
19	ticket-20250514061810945637-1747192690539	Новая заявка #20250514061810945637: н	Пользователь: undefined (qwe@qwe.ru)\nТема: н\nСообщение:\nн\n---\nИдентификатор заявки: 20250514061810945637\nИдентификатор треда (для ответов): ticket-20250514061810945637-1747192690539	devsanya.ru	t	2025-05-14 06:18:10.778747+03	f	11	\N
20	ticket-20250507102947967730-1746588587715	Заявка #20250507102947967730 закрыта пользователем: 2345	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250507102947967730.	devsanya.ru	t	2025-05-14 06:20:21.952589+03	f	\N	\N
21	ticket-20250513053844491229-1747103924565	Заявка #20250513053844491229 закрыта пользователем: 13.05	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250513053844491229.	devsanya.ru	t	2025-05-14 06:20:29.605511+03	f	\N	\N
22	ticket-20250507102703694721-1746588423120	Заявка #20250507102703694721 закрыта пользователем: цуке	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250507102703694721.	devsanya.ru	t	2025-05-14 06:20:39.180744+03	f	\N	\N
23	ticket-20250514060815220738-1747192095924	Заявка #20250514060815220738 закрыта пользователем: 3456	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250514060815220738.	devsanya.ru	t	2025-05-14 06:20:42.49704+03	f	\N	\N
24	ticket-20250514060815220738-1747192095924	Заявка #20250514060815220738 открыта повторно: 3456	Пользователь qweqwe (qwe@qwe.ru) повторно открыл заявку #20250514060815220738.	devsanya.ru	t	2025-05-14 06:28:45.483081+03	f	\N	\N
25	ticket-20250514060815220738-1747192095924	Заявка #20250514060815220738 закрыта пользователем: 3456	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250514060815220738.	devsanya.ru	t	2025-05-14 06:28:47.633738+03	f	\N	\N
26	ticket-20250514064147239387-1747194107972	Новая заявка #20250514064147239387: 23	Пользователь: undefined (qwe@qwe.ru)\nТема: 23\nСообщение:\n23\n---\nИдентификатор заявки: 20250514064147239387\nИдентификатор треда (для ответов): ticket-20250514064147239387-1747194107972	devsanya.ru	t	2025-05-14 06:41:48.171527+03	f	11	\N
27	ticket-20250513060213184409-1747105333078	Заявка #20250513060213184409 закрыта пользователем: 13.05(2)	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250513060213184409.	devsanya.ru	t	2025-05-14 06:51:59.628932+03	f	\N	\N
28	ticket-20250514060623249172-1747191983067	Заявка #20250514060623249172 закрыта пользователем: 14.05 с файлами	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250514060623249172.	devsanya.ru	t	2025-05-14 06:52:02.876324+03	f	\N	\N
29	ticket-20250514093353075965-1747204433481	Новая заявка #20250514093353075965: j	Пользователь: undefined (qwe@qwe.ru)\nТема: j\nСообщение:\nj\n---\nИдентификатор заявки: 20250514093353075965\nИдентификатор треда (для ответов): ticket-20250514093353075965-1747204433481	devsanya.ru	t	2025-05-14 09:33:53.689711+03	f	11	\N
30	ticket-20250514093353075965-1747204433481	Заявка #20250514093353075965 закрыта пользователем: j	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250514093353075965.	devsanya.ru	t	2025-05-14 09:33:59.09182+03	f	\N	\N
31	ticket-20250515060055202631-1747278055615	Новая заявка #20250515060055202631: server_sanya	Пользователь: undefined (sanya@s.ru)\nТема: server_sanya\nСообщение:\nУпал сервер\n---\nИдентификатор заявки: 20250515060055202631\nИдентификатор треда (для ответов): ticket-20250515060055202631-1747278055615	devsanya.ru	t	2025-05-15 06:00:55.862693+03	f	12	\N
32	ticket-20250515063012196187-1747279812565	Новая заявка #20250515063012196187: 15.05	Пользователь: undefined (qwe@qwe.ru)\nТема: 15.05\nСообщение:\ntest\n---\nИдентификатор заявки: 20250515063012196187\nИдентификатор треда (для ответов): ticket-20250515063012196187-1747279812565	devsanya.ru	t	2025-05-15 06:30:12.692449+03	f	11	\N
33	ticket-20250515073434829527-1747283674554	Новая заявка #20250515073434829527: 1	Пользователь: undefined (shy@s.ru)\nТема: 1\nСообщение:\n1\n---\nИдентификатор заявки: 20250515073434829527\nИдентификатор треда (для ответов): ticket-20250515073434829527-1747283674554	devsanya.ru	t	2025-05-15 07:34:34.775181+03	f	14	\N
34	ticket-20250515074157031448-1747284117897	Новая заявка #20250515074157031448: testqwe	Пользователь: undefined (test@qwe.ru)\nТема: testqwe\nСообщение:\ntestqwe\n---\nИдентификатор заявки: 20250515074157031448\nИдентификатор треда (для ответов): ticket-20250515074157031448-1747284117897	devsanya.ru	t	2025-05-15 07:41:58.003588+03	f	15	\N
35	ticket-20250516051009385554-1747361409200	Новая заявка #20250516051009385554: 16.05	Пользователь: undefined (qwe@qwe.ru)\nТема: 16.05\nСообщение:\nПроверка входящих от тех.заявки\n---\nИдентификатор заявки: 20250516051009385554\nИдентификатор треда (для ответов): ticket-20250516051009385554-1747361409200	devsanya.ru	t	2025-05-16 05:10:09.547518+03	f	11	\N
36	ticket-20250516051009385554-1747361409200	Re: Новая заявка #20250516051009385554: 16.05	undefined писал 2025-05-16 09:10:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> Проверка входящих от тех.заявки\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516051009385554\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516051009385554-1747361409200\r\nШлем входящее, прием?	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 05:13:06.985746+03	f	11	\N
37	ticket-20250516051009385554-1747361409200	Новый ответ от пользователя по заявке #20250516051009385554: 16.05	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516051009385554:\n\nundefined писал 2025-05-16 09:10:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> Проверка входящих от тех.заявки\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516051009385554\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516051009385554-1747361409200\r\nШлем входящее, прием?	devsanya.ru	t	2025-05-16 05:13:07.184729+03	f	\N	\N
38	ticket-20250515063012196187-1747279812565	Re: Новая заявка #20250515063012196187: 15.05	undefined писал 2025-05-15 10:30:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 15.05\r\n> \r\n> Сообщение:\r\n> \r\n> test\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250515063012196187\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250515063012196187-1747279812565\r\nОтвет на вашу заявку "test"	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 05:13:57.929262+03	f	11	\N
39	ticket-20250515063012196187-1747279812565	Новый ответ от пользователя по заявке #20250515063012196187: 15.05	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250515063012196187:\n\nundefined писал 2025-05-15 10:30:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 15.05\r\n> \r\n> Сообщение:\r\n> \r\n> test\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250515063012196187\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250515063012196187-1747279812565\r\nОтвет на вашу заявку "test"	devsanya.ru	t	2025-05-16 05:13:58.008246+03	f	\N	\N
40	ticket-20250516051009385554-1747361409200	Re: 16.05 [ticket-20250516051009385554-1747361409200]	прием!	qwe@qwe.ru	f	2025-05-16 05:20:19.88735+03	f	11	\N
41	ticket-20250516051009385554-1747361409200	Re: 16.05	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516051009385554:\n\nприем!	devsanya.ru	t	2025-05-16 05:20:19.972436+03	f	\N	\N
42	ticket-20250515063012196187-1747279812565	Re: 15.05 [ticket-20250515063012196187-1747279812565]	спасибо	qwe@qwe.ru	f	2025-05-16 05:28:05.685832+03	f	11	\N
43	ticket-20250515063012196187-1747279812565	Re: 15.05	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250515063012196187:\n\nспасибо	devsanya.ru	t	2025-05-16 05:28:05.768017+03	f	\N	\N
44	ticket-20250516074440210456-1747370680461	Re: Новая заявка #20250516074440210456: 16.05 [Thread#ticket-20250516074440210456-1747370680461]	undefined писал 2025-05-16 11:44:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> Проверка на переписку\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516074440210456\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516074440210456-1747370680461\r\nОтвечаю на проверку	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 07:44:52.771637+03	f	11	\N
45	ticket-20250516074440210456-1747370680461	Re: 16.05 [ticket-20250516074440210456-1747370680461]	Ответ пришел, жду ответ номер 2	qwe@qwe.ru	f	2025-05-16 07:45:08.643633+03	f	11	\N
46	ticket-20250516075855439556-1747371535307	Заявка #20250516075855439556: Новая заявка 16.05 [Thread#ticket-20250516075855439556-1747371535307]	Пользователь: undefined (qwe@qwe.ru)\nТема: 16.05\nСообщение:\n1\n---\nИдентификатор заявки: 20250516075855439556\nИдентификатор треда (для ответов): ticket-20250516075855439556-1747371535307	devsanya.ru	t	2025-05-16 07:58:55.550201+03	f	11	\N
47	ticket-20250516075855439556-1747371535307	Re: Заявка #20250516075855439556: Новая заявка 16.05 [Thread#ticket-20250516075855439556-1747371535307]	undefined писал 2025-05-16 11:58:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> 1\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516075855439556\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516075855439556-1747371535307\r\n2	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 07:59:01.636487+03	f	11	\N
48	ticket-20250516075855439556-1747371535307	Заявка #20250516075855439556: Новый ответ от пользователя по заявке 16.05 [Thread#ticket-20250516075855439556-1747371535307]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516075855439556:\n\nundefined писал 2025-05-16 11:58:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> 1\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516075855439556\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516075855439556-1747371535307\r\n2	devsanya.ru	t	2025-05-16 07:59:01.674785+03	f	\N	\N
49	ticket-20250516075855439556-1747371535307	Re: 16.05 [ticket-20250516075855439556-1747371535307]	3	qwe@qwe.ru	f	2025-05-16 07:59:12.072233+03	f	11	\N
50	ticket-20250516075855439556-1747371535307	Re: 16.05 [Thread#ticket-20250516075855439556-1747371535307]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516075855439556:\n\n3	devsanya.ru	t	2025-05-16 07:59:12.149658+03	f	\N	\N
51	ticket-20250516081350163472-1747372430792	Заявка #20250516081350163472: Новая 1 [Thread#ticket-20250516081350163472-1747372430792]	Пользователь: undefined (qwe@qwe.ru)\nТема: 1\nСообщение:\n1\n---\nИдентификатор заявки: 20250516081350163472\nИдентификатор треда (для ответов): ticket-20250516081350163472-1747372430792	devsanya.ru	t	2025-05-16 08:13:51.029925+03	f	11	\N
52	ticket-20250516081350163472-1747372430792	Re: Заявка #20250516081350163472: Новая 1 [Thread#ticket-20250516081350163472-1747372430792]	undefined писал 2025-05-16 12:13:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 1\r\n> \r\n> Сообщение:\r\n> \r\n> 1\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516081350163472\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516081350163472-1747372430792\r\n2	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:13:58.06819+03	f	11	\N
53	ticket-20250516081350163472-1747372430792	Заявка #20250516081350163472: Новый ответ от пользователя по заявке 1 [Thread#ticket-20250516081350163472-1747372430792]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516081350163472:\n\nundefined писал 2025-05-16 12:13:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 1\r\n> \r\n> Сообщение:\r\n> \r\n> 1\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516081350163472\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516081350163472-1747372430792\r\n2	devsanya.ru	t	2025-05-16 08:13:58.148283+03	f	\N	\N
54	ticket-20250516081350163472-1747372430792	Re: 1 [ticket-20250516081350163472-1747372430792]	3	qwe@qwe.ru	f	2025-05-16 08:14:03.448935+03	f	11	\N
55	ticket-20250516081350163472-1747372430792	Re: 1 [Thread#ticket-20250516081350163472-1747372430792]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516081350163472:\n\n3	devsanya.ru	t	2025-05-16 08:14:03.494007+03	f	\N	\N
56	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новая 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь: undefined (qwe@qwe.ru)\nТема: 16.05 12:26\nСообщение:\n16.05 12:26\n---\nИдентификатор заявки: 20250516082646907539\nИдентификатор треда (для ответов): ticket-20250516082646907539-1747373206318	devsanya.ru	t	2025-05-16 08:26:46.547295+03	f	11	\N
57	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: Новая 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	undefined писал 2025-05-16 12:26:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> 16.05 12:26\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516082646907539\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516082646907539-1747373206318\r\n16.05 12:26 ответ	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:26:57.926782+03	f	11	\N
58	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новый ответ от пользователя по заявке 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516082646907539:\n\nundefined писал 2025-05-16 12:26:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> 16.05 12:26\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516082646907539\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516082646907539-1747373206318\r\n16.05 12:26 ответ	devsanya.ru	t	2025-05-16 08:26:57.996517+03	f	\N	\N
59	ticket-20250516082646907539-1747373206318	Re: 16.05 12:26 [ticket-20250516082646907539-1747373206318]	16.05 12:26 вопрос 2	qwe@qwe.ru	f	2025-05-16 08:27:09.16095+03	f	11	\N
60	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516082646907539:\n\n16.05 12:26 вопрос 2	devsanya.ru	t	2025-05-16 08:27:09.224023+03	f	\N	\N
61	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Ваш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> 16.05 12:26 вопрос 2\r\nответ 2	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:27:25.372639+03	f	11	\N
62	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новый ответ от пользователя по заявке 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516082646907539:\n\nВаш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> 16.05 12:26 вопрос 2\r\nответ 2	devsanya.ru	t	2025-05-16 08:27:25.432876+03	f	\N	\N
63	ticket-20250516082646907539-1747373206318	Re: 16.05 12:26 [ticket-20250516082646907539-1747373206318]	вопрос 3	qwe@qwe.ru	f	2025-05-16 08:27:46.756726+03	f	11	\N
64	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516082646907539:\n\nвопрос 3	devsanya.ru	t	2025-05-16 08:27:46.814794+03	f	\N	\N
65	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Ваш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 3\r\nответ 3	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:27:56.242272+03	f	11	\N
66	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новый ответ от пользователя по заявке 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516082646907539:\n\nВаш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 3\r\nответ 3	devsanya.ru	t	2025-05-16 08:27:56.281261+03	f	\N	\N
67	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Ваш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 3\r\nответ 3	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:28:00.892734+03	f	11	\N
68	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новый ответ от пользователя по заявке 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516082646907539:\n\nВаш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 3\r\nответ 3	devsanya.ru	t	2025-05-16 08:28:00.929657+03	f	\N	\N
69	ticket-20250516082646907539-1747373206318	Re: 16.05 12:26 [ticket-20250516082646907539-1747373206318]	вопрос 4	qwe@qwe.ru	f	2025-05-16 08:42:07.558077+03	f	11	\N
70	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516082646907539:\n\nвопрос 4	devsanya.ru	t	2025-05-16 08:42:07.70953+03	f	\N	\N
71	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Ваш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 4\r\nответ 4	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:42:19.200014+03	f	11	\N
72	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новый ответ от пользователя по заявке 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516082646907539:\n\nВаш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 4\r\nответ 4	devsanya.ru	t	2025-05-16 08:42:19.2665+03	f	\N	\N
73	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Ваш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 4\r\nответ 4	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:42:24.877312+03	f	11	\N
74	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новый ответ от пользователя по заявке 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516082646907539:\n\nВаш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 4\r\nответ 4	devsanya.ru	t	2025-05-16 08:42:24.910307+03	f	\N	\N
75	ticket-20250516082646907539-1747373206318	Re: 16.05 12:26 [ticket-20250516082646907539-1747373206318]	вопрос 5	qwe@qwe.ru	f	2025-05-16 08:42:54.974105+03	f	11	\N
76	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516082646907539:\n\nвопрос 5	devsanya.ru	t	2025-05-16 08:42:55.046482+03	f	\N	\N
77	ticket-20250516082646907539-1747373206318	Re: Заявка #20250516082646907539: 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Ваш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 5\r\nответ 5	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:43:07.828366+03	f	11	\N
78	ticket-20250516082646907539-1747373206318	Заявка #20250516082646907539: Новый ответ от пользователя по заявке 16.05 12:26 [Thread#ticket-20250516082646907539-1747373206318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516082646907539:\n\nВаш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 5\r\nответ 5	devsanya.ru	t	2025-05-16 08:43:07.934153+03	f	\N	\N
79	ticket-20250516085200699547-1747374720134	Заявка #20250516085200699547: Новая С телефона [Thread#ticket-20250516085200699547-1747374720134]	Пользователь: undefined (mob@qwe.ru)\nТема: С телефона\nСообщение:\nС телефона\n---\nИдентификатор заявки: 20250516085200699547\nИдентификатор треда (для ответов): ticket-20250516085200699547-1747374720134	devsanya.ru	t	2025-05-16 08:52:00.215929+03	f	16	\N
80	ticket-20250516085200699547-1747374720134	Re: Заявка #20250516085200699547: Новая С телефона [Thread#ticket-20250516085200699547-1747374720134]	undefined писал 2025-05-16 12:52:\r\n> Пользователь: undefined (mob@qwe.ru)\r\n> \r\n> Тема: С телефона\r\n> \r\n> Сообщение:\r\n> \r\n> С телефона\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516085200699547\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516085200699547-1747374720134\r\nотвечаю	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:52:12.713941+03	f	16	\N
81	ticket-20250516085200699547-1747374720134	Заявка #20250516085200699547: Новый ответ от пользователя по заявке С телефона [Thread#ticket-20250516085200699547-1747374720134]	Пользователь Mob (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516085200699547:\n\nundefined писал 2025-05-16 12:52:\r\n> Пользователь: undefined (mob@qwe.ru)\r\n> \r\n> Тема: С телефона\r\n> \r\n> Сообщение:\r\n> \r\n> С телефона\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516085200699547\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516085200699547-1747374720134\r\nотвечаю	devsanya.ru	t	2025-05-16 08:52:12.789748+03	f	\N	\N
82	ticket-20250516085200699547-1747374720134	Re: С телефона [ticket-20250516085200699547-1747374720134]	Отвечаю с телефона	mob@qwe.ru	f	2025-05-16 08:52:27.100295+03	f	16	\N
83	ticket-20250516085200699547-1747374720134	Re: Заявка #20250516085200699547: С телефона [Thread#ticket-20250516085200699547-1747374720134]	Пользователь Mob (mob@qwe.ru) добавил новое сообщение в заявку #20250516085200699547:\n\nОтвечаю с телефона	devsanya.ru	t	2025-05-16 08:52:27.177151+03	f	\N	\N
84	ticket-20250516085200699547-1747374720134	Re: Заявка #20250516085200699547: С телефона [Thread#ticket-20250516085200699547-1747374720134]	Ваш Сайт ИНТ писал 2025-05-16 12:52:\r\n> Пользователь Mob (mob@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516085200699547\r\n> \r\n> Тема: С телефона\r\n> \r\n> Сообщение:\r\n> \r\n> Отвечаю с телефона\r\nотвечаю на ответ с телефона	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 08:52:41.32549+03	f	16	\N
85	ticket-20250516085200699547-1747374720134	Заявка #20250516085200699547: Новый ответ от пользователя по заявке С телефона [Thread#ticket-20250516085200699547-1747374720134]	Пользователь Mob (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516085200699547:\n\nВаш Сайт ИНТ писал 2025-05-16 12:52:\r\n> Пользователь Mob (mob@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516085200699547\r\n> \r\n> Тема: С телефона\r\n> \r\n> Сообщение:\r\n> \r\n> Отвечаю с телефона\r\nотвечаю на ответ с телефона	devsanya.ru	t	2025-05-16 08:52:41.389412+03	f	\N	\N
86	ticket-20250516093408021423-1747377248981	Заявка #20250516093408021423: Новая 23423423423432432 [Thread#ticket-20250516093408021423-1747377248981]	Пользователь: undefined (qwe@qwe.ru)\nТема: 23423423423432432\nСообщение:\n423432423423424234\n---\nИдентификатор заявки: 20250516093408021423\nИдентификатор треда (для ответов): ticket-20250516093408021423-1747377248981	devsanya.ru	t	2025-05-16 09:34:09.196366+03	f	11	\N
87	ticket-20250516093408021423-1747377248981	Re: Заявка #20250516093408021423: Новая 23423423423432432 [Thread#ticket-20250516093408021423-1747377248981]	undefined писал 2025-05-16 13:34:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 23423423423432432\r\n> \r\n> Сообщение:\r\n> \r\n> 423432423423424234\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516093408021423\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516093408021423-1747377248981\r\nДокумент увидел	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 09:34:27.356867+03	f	11	\N
88	ticket-20250516093408021423-1747377248981	Заявка #20250516093408021423: Новый ответ от пользователя по заявке 23423423423432432 [Thread#ticket-20250516093408021423-1747377248981]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516093408021423:\n\nundefined писал 2025-05-16 13:34:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 23423423423432432\r\n> \r\n> Сообщение:\r\n> \r\n> 423432423423424234\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516093408021423\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516093408021423-1747377248981\r\nДокумент увидел	devsanya.ru	t	2025-05-16 09:34:27.534107+03	f	\N	\N
89	ticket-20250516100116051682-1747378876040	Заявка #20250516100116051682: Новая 14:01 [Thread#ticket-20250516100116051682-1747378876040]	Пользователь: undefined (qwe@qwe.ru)\nТема: 14:01\nСообщение:\n14:01\n---\nИдентификатор заявки: 20250516100116051682\nИдентификатор треда (для ответов): ticket-20250516100116051682-1747378876040	devsanya.ru	t	2025-05-16 10:01:16.216329+03	f	11	\N
90	ticket-20250516100116051682-1747378876040	Re: Заявка #20250516100116051682: Новая 14:01 [Thread#ticket-20250516100116051682-1747378876040]	undefined писал 2025-05-16 14:01:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 14:01\r\n> \r\n> Сообщение:\r\n> \r\n> 14:01\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516100116051682\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516100116051682-1747378876040\r\nда, сейчас 14:01	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 10:01:27.910498+03	f	11	\N
91	ticket-20250516100116051682-1747378876040	Заявка #20250516100116051682: Новый ответ от пользователя по заявке 14:01 [Thread#ticket-20250516100116051682-1747378876040]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516100116051682:\n\nundefined писал 2025-05-16 14:01:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 14:01\r\n> \r\n> Сообщение:\r\n> \r\n> 14:01\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516100116051682\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516100116051682-1747378876040\r\nда, сейчас 14:01	devsanya.ru	t	2025-05-16 10:01:27.989073+03	f	\N	\N
92	ticket-20250516100116051682-1747378876040	Re: 14:01 [ticket-20250516100116051682-1747378876040]	спасибо	qwe@qwe.ru	f	2025-05-16 10:01:38.559835+03	f	11	\N
93	ticket-20250516100116051682-1747378876040	Re: Заявка #20250516100116051682: 14:01 [Thread#ticket-20250516100116051682-1747378876040]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250516100116051682:\n\nспасибо	devsanya.ru	t	2025-05-16 10:01:38.671475+03	f	\N	\N
94	ticket-20250516100116051682-1747378876040	Re: Заявка #20250516100116051682: 14:01 [Thread#ticket-20250516100116051682-1747378876040]	Ваш Сайт ИНТ писал 2025-05-16 14:01:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516100116051682\r\n> \r\n> Тема: 14:01\r\n> \r\n> Сообщение:\r\n> \r\n> спасибо\r\nпожалуйста	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-16 10:01:46.573446+03	f	11	\N
95	ticket-20250516100116051682-1747378876040	Заявка #20250516100116051682: Новый ответ от пользователя по заявке 14:01 [Thread#ticket-20250516100116051682-1747378876040]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250516100116051682:\n\nВаш Сайт ИНТ писал 2025-05-16 14:01:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516100116051682\r\n> \r\n> Тема: 14:01\r\n> \r\n> Сообщение:\r\n> \r\n> спасибо\r\nпожалуйста	devsanya.ru	t	2025-05-16 10:01:46.623232+03	f	\N	\N
96	ticket-20250518100223824219-1747551743074	Заявка #20250518100223824219: Новая Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	Пользователь: undefined (tamara200148@gmail.com)\nТема: Тестовая заявка\nСообщение:\nЗаявка для теста\n---\nИдентификатор заявки: 20250518100223824219\nИдентификатор треда (для ответов): ticket-20250518100223824219-1747551743074	devsanya.ru	t	2025-05-18 10:02:23.315486+03	f	17	\N
97	ticket-20250518100223824219-1747551743074	Re: Заявка #20250518100223824219: Новая Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	undefined писал 2025-05-18 14:02:\r\n> Пользователь: undefined (tamara200148@gmail.com)\r\n> \r\n> Тема: Тестовая заявка\r\n> \r\n> Сообщение:\r\n> \r\n> Заявка для теста\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250518100223824219\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250518100223824219-1747551743074\r\nТРИПЛКАААААААААААААААААААААААААААААААААААААААААААААААААААААААА	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-18 10:02:50.491652+03	f	17	\N
98	ticket-20250518100223824219-1747551743074	Заявка #20250518100223824219: Новый ответ от пользователя по заявке Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	Пользователь Павлова Тамара Махмутовна (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250518100223824219:\n\nundefined писал 2025-05-18 14:02:\r\n> Пользователь: undefined (tamara200148@gmail.com)\r\n> \r\n> Тема: Тестовая заявка\r\n> \r\n> Сообщение:\r\n> \r\n> Заявка для теста\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250518100223824219\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250518100223824219-1747551743074\r\nТРИПЛКАААААААААААААААААААААААААААААААААААААААААААААААААААААААА	devsanya.ru	t	2025-05-18 10:02:50.568676+03	f	\N	\N
99	ticket-20250518100223824219-1747551743074	Re: Тестовая заявка [ticket-20250518100223824219-1747551743074]	Ересь победит	tamara200148@gmail.com	f	2025-05-18 10:03:54.838956+03	f	17	\N
100	ticket-20250518100223824219-1747551743074	Re: Заявка #20250518100223824219: Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	Пользователь Павлова Тамара Махмутовна (tamara200148@gmail.com) добавил новое сообщение в заявку #20250518100223824219:\n\nЕресь победит	devsanya.ru	t	2025-05-18 10:03:54.905018+03	f	\N	\N
101	ticket-20250518100223824219-1747551743074	Re: Заявка #20250518100223824219: Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	Ваш Сайт ИНТ писал 2025-05-18 14:03:\r\n> Пользователь Павлова Тамара\r\n> Махмутовна (tamara200148@gmail.com) добавил\r\n> новое сообщение в заявку:\r\n> \r\n> Номер заявки: 20250518100223824219\r\n> \r\n> Тема: Тестовая заявка\r\n> \r\n> Сообщение:\r\n> \r\n> Ересь победит\r\nи тепя луплюююююююююююююююююююююююююююююю \r\nмаяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-18 10:04:57.347114+03	f	17	\N
102	ticket-20250518100223824219-1747551743074	Заявка #20250518100223824219: Новый ответ от пользователя по заявке Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	Пользователь Павлова Тамара Махмутовна (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250518100223824219:\n\nВаш Сайт ИНТ писал 2025-05-18 14:03:\r\n> Пользователь Павлова Тамара\r\n> Махмутовна (tamara200148@gmail.com) добавил\r\n> новое сообщение в заявку:\r\n> \r\n> Номер заявки: 20250518100223824219\r\n> \r\n> Тема: Тестовая заявка\r\n> \r\n> Сообщение:\r\n> \r\n> Ересь победит\r\nи тепя луплюююююююююююююююююююююююююююююю \r\nмаяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя	devsanya.ru	t	2025-05-18 10:04:57.411992+03	f	\N	\N
103	ticket-20250518100223824219-1747551743074	Заявка #20250518100223824219 закрыта пользователем: Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	Пользователь Павлова Тамара Махмутовна (tamara200148@gmail.com) закрыл заявку #20250518100223824219.	devsanya.ru	t	2025-05-18 10:06:06.907131+03	f	\N	\N
104	ticket-20250518100657069589-1747552017927	Заявка #20250518100657069589: Новая Моя заявка номер 2 [Thread#ticket-20250518100657069589-1747552017927]	Пользователь: undefined (tamara200148@gmail.com)\nТема: Моя заявка номер 2\nСообщение:\nТуц туц туц туц туц\n---\nИдентификатор заявки: 20250518100657069589\nИдентификатор треда (для ответов): ticket-20250518100657069589-1747552017927	devsanya.ru	t	2025-05-18 10:06:57.991951+03	f	17	\N
105	ticket-20250518100223824219-1747551743074	Заявка #20250518100223824219 открыта повторно: Тестовая заявка [Thread#ticket-20250518100223824219-1747551743074]	Пользователь Павлова Тамара Махмутовна (tamara200148@gmail.com) повторно открыл заявку #20250518100223824219.	devsanya.ru	t	2025-05-18 10:07:35.844577+03	f	\N	\N
106	ticket-20250519035626133908-1747616186529	Заявка #20250519035626133908: Новая 19.05 [Thread#ticket-20250519035626133908-1747616186529]	Пользователь: undefined (qwe@qwe.ru)\nТема: 19.05\nСообщение:\n19.05\n---\nИдентификатор заявки: 20250519035626133908\nИдентификатор треда (для ответов): ticket-20250519035626133908-1747616186529	devsanya.ru	t	2025-05-19 03:56:26.765219+03	f	11	\N
107	ticket-20250519035626133908-1747616186529	Re: Заявка #20250519035626133908: Новая 19.05 [Thread#ticket-20250519035626133908-1747616186529]	undefined писал 2025-05-19 07:56:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 19.05\r\n> \r\n> Сообщение:\r\n> \r\n> 19.05\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519035626133908\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519035626133908-1747616186529\r\ntt	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-19 03:57:00.978513+03	f	11	\N
108	ticket-20250519035626133908-1747616186529	Заявка #20250519035626133908: Новый ответ от пользователя по заявке 19.05 [Thread#ticket-20250519035626133908-1747616186529]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250519035626133908:\n\nundefined писал 2025-05-19 07:56:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 19.05\r\n> \r\n> Сообщение:\r\n> \r\n> 19.05\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519035626133908\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519035626133908-1747616186529\r\ntt	devsanya.ru	t	2025-05-19 03:57:01.048092+03	f	\N	\N
109	ticket-20250519043856610111-1747618736142	Заявка #20250519043856610111: Новая 1 [Thread#ticket-20250519043856610111-1747618736142]	Пользователь: undefined (qwe@qwe.ru)\nТема: 1\nСообщение:\n1\n---\nИдентификатор заявки: 20250519043856610111\nИдентификатор треда (для ответов): ticket-20250519043856610111-1747618736142	devsanya.ru	t	2025-05-19 04:38:56.262693+03	f	11	\N
110	ticket-20250519044905206402-1747619345224	Заявка #20250519044905206402: Новая pdf [Thread#ticket-20250519044905206402-1747619345224]	Пользователь: undefined (qwe@qwe.ru)\nТема: pdf\nСообщение:\npdf\n---\nИдентификатор заявки: 20250519044905206402\nИдентификатор треда (для ответов): ticket-20250519044905206402-1747619345224	devsanya.ru	t	2025-05-19 04:49:05.367815+03	f	11	\N
111	ticket-20250519044942465318-1747619382318	Заявка #20250519044942465318: Новая txt [Thread#ticket-20250519044942465318-1747619382318]	Пользователь: undefined (qwe@qwe.ru)\nТема: txt\nСообщение:\ntxt\n---\nИдентификатор заявки: 20250519044942465318\nИдентификатор треда (для ответов): ticket-20250519044942465318-1747619382318	devsanya.ru	t	2025-05-19 04:49:42.386845+03	f	11	\N
112	ticket-20250519044942465318-1747619382318	Re: Заявка #20250519044942465318: Новая txt [Thread#ticket-20250519044942465318-1747619382318]	undefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\ntxtxtx	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-19 04:53:54.06763+03	f	11	\N
113	ticket-20250519044942465318-1747619382318	Заявка #20250519044942465318: Новый ответ от пользователя по заявке txt [Thread#ticket-20250519044942465318-1747619382318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250519044942465318:\n\nundefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\ntxtxtx	devsanya.ru	t	2025-05-19 04:53:54.14763+03	f	\N	\N
114	ticket-20250519044942465318-1747619382318	Re: Заявка #20250519044942465318: Новая txt [Thread#ticket-20250519044942465318-1747619382318]	--=_1bdef548719f9061c1e1404e2b30705a\r\nContent-Transfer-Encoding: 8bit\r\nContent-Type: text/plain; charset=UTF-8;\r\n format=flowed\r\n\r\nundefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\n\r\n--=_1bdef548719f9061c1e1404e2b30705a\r\nContent-Transfer-Encoding: base64\r\nContent-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document;\r\n name="=?UTF-8?Q?=D1=83=D1=87=D0=B5=D0=B1=D0=BD=D1=8B=D0=B9_=D0=BE=D1=82?=\r\n =?UTF-8?Q?=D0=BF=D1=83=D1=81=D0=BA=2Edocx?="\r\nContent-Disposition: attachment;\r\n filename*0*=UTF-8''%D1%83%D1%87%D0%B5%D0%B1%D0%BD%D1%8B%D0%B9%20%D0%BE%D1;\r\n filename*1*=%82%D0%BF%D1%83%D1%81%D0%BA.docx;\r\n size=13766\r\n\r\nUEsDBBQABgAIAAAAIQD4K3FghQEAAI4FAAATAAgCW0NvbnRlbnRfVHlwZXNdLnhtbCCiBAIooAAC\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC0\r\nVMtOwzAQvCPxD5GvKHHLASHUtAcoR6hEEWdjb1qLxLa87uvv2SRtVKBNKgqXSI69M7Mzaw9G6yKP\r\nluBRW5OyftJjERhplTazlL1OH+NbFmEQRoncGkjZBpCNhpcXg+nGAUZUbTBl8xDcHeco51AITKwD\r\nQzuZ9YUItPQz7oT8EDPg173eDZfWBDAhDiUGGw4eIBOLPETjNf2ulXjIkUX39cGSK2XCuVxLEUgp\r\nXxr1jSXeMiRUWZ3BuXZ4RTIYP8hQ7hwn2NY9kzVeK4gmwocnUZAMvrJecWXloqAeknaYAzptlmkJ\r\nTX2J5ryVgEieF3nS7BRCm53+ozowbHLAv1dR47bRk86Jtw455XI2P5TJK1AxWeHABw1NdB2tv+kw\r\nH2cZSBq07iwKjEvDk7q9vdq2TqvAEUKggE4h+Tr+cVfgO+ROCYFuF/Dq2z+h13YZFUwnZUYXcCre\r\nczib78ecN9CdIlbw/vJv7u+Btwlppl1a/wszdo9TWX1gxnn1mg4/AQAA//8DAFBLAwQUAAYACAAA\r\nACEAHpEat/MAAABOAgAACwAIAl9yZWxzLy5yZWxzIKIEAiigAAIAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIyS20oDQQyG7wXfYch9N9sKItLZ\r\n3kihdyLrA4SZ7AF3Dsyk2r69oyC6UNte5vTny0/Wm4Ob1DunPAavYVnVoNibYEffa3htt4sHUFnI\r\nW5qCZw1HzrBpbm/WLzyRlKE8jDGrouKzhkEkPiJmM7CjXIXIvlS6kBxJCVOPkcwb9Yyrur7H9FcD\r\nmpmm2lkNaWfvQLXHWDZf1g5dNxp+Cmbv2MuJFcgHYW/ZLmIqbEnGco1qKfUsGmwwzyWdkWKsCjbg\r\naaLV9UT/X4uOhSwJoQmJz/N8dZwDWl4PdNmiecevOx8hWSwWfXv7Q4OzL2g+AQAA//8DAFBLAwQU\r\nAAYACAAAACEAU1ivTyUBAAC5AwAAHAAIAXdvcmQvX3JlbHMvZG9jdW1lbnQueG1sLnJlbHMgogQB\r\n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\r\nY3RzLnhtbFBLBQYAAAAADAAMAAkDAACnMgAAAAA=\r\n--=_1bdef548719f9061c1e1404e2b30705a--\r\n	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-19 05:00:50.473529+03	f	11	\N
115	ticket-20250519044942465318-1747619382318	Заявка #20250519044942465318: Новый ответ от пользователя по заявке txt [Thread#ticket-20250519044942465318-1747619382318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250519044942465318:\n\n--=_1bdef548719f9061c1e1404e2b30705a\r\nContent-Transfer-Encoding: 8bit\r\nContent-Type: text/plain; charset=UTF-8;\r\n format=flowed\r\n\r\nundefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\n\r\n--=_1bdef548719f9061c1e1404e2b30705a\r\nContent-Transfer-Encoding: base64\r\nContent-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document;\r\n name="=?UTF-8?Q?=D1=83=D1=87=D0=B5=D0=B1=D0=BD=D1=8B=D0=B9_=D0=BE=D1=82?=\r\n =?UTF-8?Q?=D0=BF=D1=83=D1=81=D0=BA=2Edocx?="\r\nContent-Disposition: attachment;\r\n filename*0*=UTF-8''%D1%83%D1%87%D0%B5%D0%B1%D0%BD%D1%8B%D0%B9%20%D0%BE%D1;\r\n filename*1*=%82%D0%BF%D1%83%D1%81%D0%BA.docx;\r\n size=13766\r\n\r\nUEsDBBQABgAIAAAAIQD4K3FghQEAAI4FAAATAAgCW0NvbnRlbnRfVHlwZXNdLnhtbCCiBAIooAAC\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC0\r\nVMtOwzAQvCPxD5GvKHHLASHUtAcoR6hEEWdjb1qLxLa87uvv2SRtVKBNKgqXSI69M7Mzaw9G6yKP\r\nluBRW5OyftJjERhplTazlL1OH+NbFmEQRoncGkjZBpCNhpcXg+nGAUZUbTBl8xDcHeco51AITKwD\r\nQzuZ9YUItPQz7oT8EDPg173eDZfWBDAhDiUGGw4eIBOLPETjNf2ulXjIkUX39cGSK2XCuVxLEUgp\r\nXxr1jSXeMiRUWZ3BuXZ4RTIYP8hQ7hwn2NY9kzVeK4gmwocnUZAMvrJecWXloqAeknaYAzptlmkJ\r\nTX2J5ryVgEieF3nS7BRCm53+ozowbHLAv1dR47bRk86Jtw455XI2P5TJK1AxWeHABw1NdB2tv+kw\r\nH2cZSBq07iwKjEvDk7q9vdq2TqvAEUKggE4h+Tr+cVfgO+ROCYFuF/Dq2z+h13YZFUwnZUYXcCre\r\nczib78ecN9CdIlbw/vJv7u+Btwlppl1a/wszdo9TWX1gxnn1mg4/AQAA//8DAFBLAwQUAAYACAAA\r\nACEAHpEat/MAAABOAgAACwAIAl9yZWxzLy5yZWxzIKIEAiigAAIAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIyS20oDQQyG7wXfYch9N9sKItLZ\r\n3kihdyLrA4SZ7AF3Dsyk2r69oyC6UNte5vTny0/Wm4Ob1DunPAavYVnVoNibYEffa3htt4sHUFnI\r\nW5qCZw1HzrBpbm/WLzyRlKE8jDGrouKzhkEkPiJmM7CjXIXIvlS6kBxJCVOPkcwb9Yyrur7H9FcD\r\nmpmm2lkNaWfvQLXHWDZf1g5dNxp+Cmbv2MuJFcgHYW/ZLmIqbEnGco1qKfUsGmwwzyWdkWKsCjbg\r\naaLV9UT/X4uOhSwJoQmJz/N8dZwDWl4PdNmiecevOx8hWSwWfXv7Q4OzL2g+AQAA//8DAFBLAwQU\r\nAAYACAAAACEAU1ivTyUBAAC5AwAAHAAIAXdvcmQvX3JlbHMvZG9jdW1lbnQueG1sLnJlbHMgogQB\r\n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\r\nY3RzLnhtbFBLBQYAAAAADAAMAAkDAACnMgAAAAA=\r\n--=_1bdef548719f9061c1e1404e2b30705a--\r\n	devsanya.ru	t	2025-05-19 05:00:50.596922+03	f	\N	\N
116	ticket-20250519044942465318-1747619382318	Заявка #20250519044942465318 закрыта пользователем: txt [Thread#ticket-20250519044942465318-1747619382318]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250519044942465318.	devsanya.ru	t	2025-05-19 05:02:50.324418+03	f	\N	\N
117	ticket-20250519044905206402-1747619345224	Re: Заявка #20250519044905206402: Новая pdf [Thread#ticket-20250519044905206402-1747619345224]	undefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: pdf\r\n> \r\n> Сообщение:\r\n> \r\n> pdf\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044905206402\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044905206402-1747619345224\r\n111	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-19 08:15:41.311666+03	f	11	\N
118	ticket-20250519044905206402-1747619345224	Заявка #20250519044905206402: Новый ответ от пользователя по заявке pdf [Thread#ticket-20250519044905206402-1747619345224]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250519044905206402:\n\nundefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: pdf\r\n> \r\n> Сообщение:\r\n> \r\n> pdf\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044905206402\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044905206402-1747619345224\r\n111	devsanya.ru	t	2025-05-19 08:15:41.45541+03	f	\N	\N
119	ticket-20250519044942465318-1747619382318	Re: Заявка #20250519044942465318: Новая txt [Thread#ticket-20250519044942465318-1747619382318]	undefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\n	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-19 08:22:27.361831+03	f	11	\N
120	ticket-20250519044942465318-1747619382318	Заявка #20250519044942465318: Новый ответ от пользователя по заявке txt [Thread#ticket-20250519044942465318-1747619382318]	Пользователь qweqwe (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250519044942465318:\n\nundefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\n	devsanya.ru	t	2025-05-19 08:22:27.457063+03	f	\N	\N
121	ticket-20250519101716014185-1747639036246	Заявка #20250519101716014185: Новая цуе [Thread#ticket-20250519101716014185-1747639036246]	Пользователь: undefined (qwe@qwe.ru)\nТема: цуе\nСообщение:\nцуке\n---\nИдентификатор заявки: 20250519101716014185\nИдентификатор треда (для ответов): ticket-20250519101716014185-1747639036246	devsanya.ru	t	2025-05-19 10:17:16.388031+03	f	11	\N
122	ticket-20250519101716014185-1747639036246	Re: цуе [ticket-20250519101716014185-1747639036246]	asfd	qwe@qwe.ru	f	2025-05-20 04:27:35.531371+03	f	11	\N
123	ticket-20250519101716014185-1747639036246	Re: Заявка #20250519101716014185: цуе [Thread#ticket-20250519101716014185-1747639036246]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250519101716014185:\n\nasfd	devsanya.ru	t	2025-05-20 04:27:35.79222+03	f	\N	\N
124	ticket-20250519101716014185-1747639036246	Re: цуе [ticket-20250519101716014185-1747639036246]	ййй	qwe@qwe.ru	f	2025-05-20 04:38:18.980541+03	f	11	\N
125	ticket-20250519101716014185-1747639036246	Re: Заявка #20250519101716014185: цуе [Thread#ticket-20250519101716014185-1747639036246]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250519101716014185:\n\nййй	devsanya.ru	t	2025-05-20 04:38:19.285619+03	f	\N	\N
126	ticket-20250520045911858996-1747706351359	Заявка #20250520045911858996: Новая qwe [Thread#ticket-20250520045911858996-1747706351359]	Пользователь: undefined (b@b.ru)\nТема: qwe\nСообщение:\nqwer\n---\nИдентификатор заявки: 20250520045911858996\nИдентификатор треда (для ответов): ticket-20250520045911858996-1747706351359	devsanya.ru	t	2025-05-20 04:59:11.669561+03	f	22	\N
127	ticket-20250520045911858996-1747706351359	Re: qwe [ticket-20250520045911858996-1747706351359]	rrrr	b@b.ru	f	2025-05-20 04:59:24.903934+03	f	22	\N
128	ticket-20250520045911858996-1747706351359	Re: Заявка #20250520045911858996: qwe [Thread#ticket-20250520045911858996-1747706351359]	Пользователь BIO (b@b.ru) добавил новое сообщение в заявку #20250520045911858996:\n\nrrrr	devsanya.ru	t	2025-05-20 04:59:25.075106+03	f	\N	\N
129	ticket-20250520045911858996-1747706351359	Re: Заявка #20250520045911858996: qwe [Thread#ticket-20250520045911858996-1747706351359]	Ваш Сайт ИНТ писал 2025-05-20 08:59:\r\n> Пользователь BIO (b@b.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250520045911858996\r\n> \r\n> Тема: qwe\r\n> \r\n> Сообщение:\r\n> \r\n> rrrr\r\nok file	mailuser <mailuser@mail.devsanya.ru>	f	2025-05-20 04:59:40.883992+03	f	22	\N
130	ticket-20250520045911858996-1747706351359	Заявка #20250520045911858996: Новый ответ от пользователя по заявке qwe [Thread#ticket-20250520045911858996-1747706351359]	Пользователь BIO (mailuser <mailuser@mail.devsanya.ru>) ответил на заявку #20250520045911858996:\n\nВаш Сайт ИНТ писал 2025-05-20 08:59:\r\n> Пользователь BIO (b@b.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250520045911858996\r\n> \r\n> Тема: qwe\r\n> \r\n> Сообщение:\r\n> \r\n> rrrr\r\nok file	devsanya.ru	t	2025-05-20 04:59:41.055468+03	f	\N	\N
131	ticket-20250520063636138033-1747712196113	Заявка #20250520063636138033: Новая aga [Thread#ticket-20250520063636138033-1747712196113]	Пользователь: undefined (qwe@qwe.ru)\nТема: aga\nСообщение:\naga\n---\nИдентификатор заявки: 20250520063636138033\nИдентификатор треда (для ответов): ticket-20250520063636138033-1747712196113	devsanya.ru	t	2025-05-20 06:36:36.323788+03	f	11	\N
132	ticket-20250520095025584024-1747723825783	Заявка #20250520095025584024: Новая Сервер Историй [Thread#ticket-20250520095025584024-1747723825783]	Пользователь: undefined (qwe@qwe.ru)\nТема: Сервер Историй\nСообщение:\nУпал вчера\n---\nИдентификатор заявки: 20250520095025584024\nИдентификатор треда (для ответов): ticket-20250520095025584024-1747723825783	devsanya.ru	t	2025-05-20 09:50:25.953395+03	f	11	\N
133	ticket-20250520095025584024-1747723825783	Re: Сервер Историй [ticket-20250520095025584024-1747723825783]	sdfg	qwe@qwe.ru	f	2025-05-20 10:45:59.844928+03	f	11	\N
134	ticket-20250520095025584024-1747723825783	Re: Заявка #20250520095025584024: Сервер Историй [Thread#ticket-20250520095025584024-1747723825783]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250520095025584024:\n\nsdfg	devsanya.ru	t	2025-05-20 10:46:00.115775+03	f	\N	\N
135	ticket-20250520045911858996-1747706351359	Re: qwe [ticket-20250520045911858996-1747706351359]	wrt	b@b.ru	f	2025-05-23 06:47:47.089842+03	f	22	\N
136	ticket-20250520045911858996-1747706351359	Re: Заявка #20250520045911858996: qwe [Thread#ticket-20250520045911858996-1747706351359]	Пользователь BIO (b@b.ru) добавил новое сообщение в заявку #20250520045911858996:\n\nwrt	devsanya.ru	t	2025-05-23 06:47:47.424967+03	f	\N	\N
137	ticket-20250527070011894328-1748318411681	Заявка #20250527070011894328: Новая Пиздец серверу истории [Thread#ticket-20250527070011894328-1748318411681]	Пользователь: Енот (a@mail.ru)\nТема: Пиздец серверу истории\nСообщение:\nВсе пропало\n---\nИдентификатор заявки: 20250527070011894328\nИдентификатор треда (для ответов): ticket-20250527070011894328-1748318411681	devsanya.ru	t	2025-05-27 07:00:11.985432+03	f	26	\N
138	ticket-20250527070052079726-1748318452367	Заявка #20250527070052079726: Новая цуеапукываываыв [Thread#ticket-20250527070052079726-1748318452367]	Пользователь: Енот (a@mail.ru)\nТема: цуеапукываываыв\nСообщение:\nаываываываыва\n---\nИдентификатор заявки: 20250527070052079726\nИдентификатор треда (для ответов): ticket-20250527070052079726-1748318452367	devsanya.ru	t	2025-05-27 07:00:52.438223+03	f	26	\N
139	ticket-20250527070052079726-1748318452367	Заявка #20250527070052079726 закрыта пользователем: цуеапукываываыв [Thread#ticket-20250527070052079726-1748318452367]	Пользователь Енот (a@mail.ru) закрыл заявку #20250527070052079726.	devsanya.ru	t	2025-05-27 07:18:53.17952+03	f	\N	\N
140	ticket-20250527070052079726-1748318452367	Заявка #20250527070052079726 открыта повторно: цуеапукываываыв [Thread#ticket-20250527070052079726-1748318452367]	Пользователь Енот (a@mail.ru) повторно открыл заявку #20250527070052079726.	devsanya.ru	t	2025-05-27 07:19:05.077494+03	f	\N	\N
141	ticket-20250527070052079726-1748318452367	Заявка #20250527070052079726 закрыта пользователем: цуеапукываываыв [Thread#ticket-20250527070052079726-1748318452367]	Пользователь Енот (a@mail.ru) закрыл заявку #20250527070052079726.	devsanya.ru	t	2025-05-27 07:19:07.397546+03	f	\N	\N
142	ticket-20250527070052079726-1748318452367	Заявка #20250527070052079726 открыта повторно: цуеапукываываыв [Thread#ticket-20250527070052079726-1748318452367]	Пользователь Енот (a@mail.ru) повторно открыл заявку #20250527070052079726.	devsanya.ru	t	2025-05-27 07:19:08.829593+03	f	\N	\N
143	ticket-20250520095025584024-1747723825783	Заявка #20250520095025584024 закрыта пользователем: Сервер Историй [Thread#ticket-20250520095025584024-1747723825783]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250520095025584024.	devsanya.ru	t	2025-05-27 08:08:27.275153+03	f	\N	\N
144	ticket-20250528055612430979-1748400972076	Заявка #20250528055612430979: Новая С той же компании [Thread#ticket-20250528055612430979-1748400972076]	Пользователь: С той же Компании (acompany@qwe.ru)\nТема: С той же компании\nСообщение:\nПишу с компании Компания\n---\nИдентификатор заявки: 20250528055612430979\nИдентификатор треда (для ответов): ticket-20250528055612430979-1748400972076	devsanya.ru	t	2025-05-28 05:56:12.305571+03	f	27	\N
145	ticket-20250528073059042172-1748406659709	Заявка #20250528073059042172: Новая тест закрытая фильтр [Thread#ticket-20250528073059042172-1748406659709]	Пользователь: С той же Компании (acompany@qwe.ru)\nТема: тест закрытая фильтр\nСообщение:\nтест закрытая фильтр\n---\nИдентификатор заявки: 20250528073059042172\nИдентификатор треда (для ответов): ticket-20250528073059042172-1748406659709	devsanya.ru	t	2025-05-28 07:30:59.892619+03	f	27	\N
146	ticket-20250528073059042172-1748406659709	Заявка #20250528073059042172 закрыта пользователем: тест закрытая фильтр [Thread#ticket-20250528073059042172-1748406659709]	Пользователь С той же Компании (acompany@qwe.ru) закрыл заявку #20250528073059042172.	devsanya.ru	t	2025-05-28 07:32:46.917754+03	f	\N	\N
147	ticket-20250528081407007870-1748409247909	Заявка #20250528081407007870: Новая Вопрос по созданию нестандартной динамики [Thread#ticket-20250528081407007870-1748409247909]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: Вопрос по созданию нестандартной динамики\nСообщение:\nцукцук\n---\nИдентификатор заявки: 20250528081407007870\nИдентификатор треда (для ответов): ticket-20250528081407007870-1748409247909	devsanya.ru	t	2025-05-28 08:14:08.006023+03	f	11	\N
148	ticket-20250528081526983290-1748409326671	Заявка #20250528081526983290: Новая Серитифкаты безопасности [Thread#ticket-20250528081526983290-1748409326671]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: Серитифкаты безопасности\nСообщение:\nКак использовать сертификаты безопасности при настройке удаленного подключения в IntegritDataTransport\n---\nИдентификатор заявки: 20250528081526983290\nИдентификатор треда (для ответов): ticket-20250528081526983290-1748409326671	devsanya.ru	t	2025-05-28 08:15:26.782298+03	f	11	\N
149	ticket-20250528081734440902-1748409454725	Заявка #20250528081734440902: Новая Функция Application.Execute [Thread#ticket-20250528081734440902-1748409454725]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: Функция Application.Execute\nСообщение:\nКакой полный перечень параметров у функции Application.Execute в IntegrityHMI\n---\nИдентификатор заявки: 20250528081734440902\nИдентификатор треда (для ответов): ticket-20250528081734440902-1748409454725	devsanya.ru	t	2025-05-28 08:17:34.820675+03	f	11	\N
150	ticket-20250528081956653103-1748409596604	Заявка #20250528081956653103: Новая Поддержка S7 [Thread#ticket-20250528081956653103-1748409596604]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: Поддержка S7\nСообщение:\nПоддерживается ли работа по протоколу S7 с контроллерами Siemens 1500 серии?\n---\nИдентификатор заявки: 20250528081956653103\nИдентификатор треда (для ответов): ticket-20250528081956653103-1748409596604	devsanya.ru	t	2025-05-28 08:19:56.740319+03	f	11	\N
151	ticket-20250528082118579644-1748409678657	Заявка #20250528082118579644: Новая Поддержка контейнеризации [Thread#ticket-20250528082118579644-1748409678657]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: Поддержка контейнеризации\nСообщение:\nУкажите полный перечень поддерживаемых систем конкретизации для IntegritySCADA\n---\nИдентификатор заявки: 20250528082118579644\nИдентификатор треда (для ответов): ticket-20250528082118579644-1748409678657	devsanya.ru	t	2025-05-28 08:21:18.731773+03	f	11	\N
152	ticket-20250528082213940287-1748409733928	Заявка #20250528082213940287: Новая Перенос лицензий [Thread#ticket-20250528082213940287-1748409733928]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: Перенос лицензий\nСообщение:\nКак перенести лицензии с одной машины на другую?\n---\nИдентификатор заявки: 20250528082213940287\nИдентификатор треда (для ответов): ticket-20250528082213940287-1748409733928	devsanya.ru	t	2025-05-28 08:22:14.000421+03	f	11	\N
153	ticket-20250528082407504967-1748409847348	Заявка #20250528082407504967: Новая Возможно ли доработать события? [Thread#ticket-20250528082407504967-1748409847348]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: Возможно ли доработать события?\nСообщение:\nВозможно ли доработать события, чтобы они проигрывали звуки в порядке приоритета с дополнительной\n---\nИдентификатор заявки: 20250528082407504967\nИдентификатор треда (для ответов): ticket-20250528082407504967-1748409847348	devsanya.ru	t	2025-05-28 08:24:07.494509+03	f	11	\N
154	ticket-20250528081526983290-1748409326671	Заявка #20250528081526983290 закрыта пользователем: Серитифкаты безопасности [Thread#ticket-20250528081526983290-1748409326671]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250528081526983290.	devsanya.ru	t	2025-05-28 09:01:29.601366+03	f	\N	\N
155	ticket-20250528081734440902-1748409454725	Заявка #20250528081734440902 закрыта пользователем: Функция Application.Execute [Thread#ticket-20250528081734440902-1748409454725]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250528081734440902.	devsanya.ru	t	2025-05-28 09:01:35.964427+03	f	\N	\N
156	ticket-20250528081956653103-1748409596604	Заявка #20250528081956653103 закрыта пользователем: Поддержка S7 [Thread#ticket-20250528081956653103-1748409596604]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250528081956653103.	devsanya.ru	t	2025-05-28 09:01:38.753104+03	f	\N	\N
157	ticket-20250528082118579644-1748409678657	Заявка #20250528082118579644 закрыта пользователем: Поддержка контейнеризации [Thread#ticket-20250528082118579644-1748409678657]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250528082118579644.	devsanya.ru	t	2025-05-28 09:01:41.573866+03	f	\N	\N
158	ticket-20250528082213940287-1748409733928	Заявка #20250528082213940287 закрыта пользователем: Перенос лицензий [Thread#ticket-20250528082213940287-1748409733928]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250528082213940287.	devsanya.ru	t	2025-05-28 09:01:45.637645+03	f	\N	\N
159	ticket-20250529060417207845-1748487857809	Заявка #20250529060417207845: Новая qwe [Thread#ticket-20250529060417207845-1748487857809]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: qwe\nСообщение:\nqwe\n---\nИдентификатор заявки: 20250529060417207845\nИдентификатор треда (для ответов): ticket-20250529060417207845-1748487857809	devsanya.ru	t	2025-05-29 06:04:18.052589+03	f	11	\N
167	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Новая 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Пользователь: qweqwe (qwe@qwe.ru)\nТема: 05.06\nСообщение:\nПроверка связи\n---\nИдентификатор заявки: 20250605052322708650\nИдентификатор треда (для ответов): ticket-20250605052322708650-1749090202328	devsanya.ru	t	2025-06-05 05:23:22.571768+03	f	11	\N
168	ticket-20250605052322708650-1749090202328	Re: 05.06	Ответ	mailuser@mail.devsanya.ru	t	2025-06-05 05:53:39.817816+03	f	\N	qwe@qwe.ru
169	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Ответ по вашей заявке 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Здравствуйте, qweqwe!\n\nСотрудник техподдержки (Техподдержка ИНТ, mailuser@mail.devsanya.ru) ответил на вашу заявку #20250605052322708650:\n\nОтвет\n\n---\nВы можете ответить на это письмо или перейти в личный кабинет на сайте.\nС уважением,\nТехподдержка ИНТ	devsanya.ru	t	2025-06-05 05:53:40.00067+03	f	\N	\N
170	ticket-20250605052322708650-1749090202328	Re: 05.06 [ticket-20250605052322708650-1749090202328]	че ответ?	qwe@qwe.ru	f	2025-06-05 05:53:57.201558+03	f	11	\N
171	ticket-20250605052322708650-1749090202328	Re: Заявка #20250605052322708650: 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250605052322708650:\n\nче ответ?	devsanya.ru	t	2025-06-05 05:53:57.313844+03	f	\N	\N
172	ticket-20250605052322708650-1749090202328	Re: 05.06	а че?	mailuser@mail.devsanya.ru	t	2025-06-05 05:54:08.066585+03	f	\N	qwe@qwe.ru
173	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Ответ по вашей заявке 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Здравствуйте, qweqwe!\n\nСотрудник техподдержки (Техподдержка ИНТ, mailuser@mail.devsanya.ru) ответил на вашу заявку #20250605052322708650:\n\nа че?\n\n---\nВы можете ответить на это письмо или перейти в личный кабинет на сайте.\nС уважением,\nТехподдержка ИНТ	devsanya.ru	t	2025-06-05 05:54:08.134214+03	f	\N	\N
174	ticket-20250605052322708650-1749090202328	Re: 05.06 [ticket-20250605052322708650-1749090202328]	rty	qwe@qwe.ru	f	2025-06-05 05:56:05.240579+03	f	11	\N
175	ticket-20250605052322708650-1749090202328	Re: Заявка #20250605052322708650: 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250605052322708650:\n\nrty	devsanya.ru	t	2025-06-05 05:56:05.392393+03	f	\N	\N
176	ticket-20250605052322708650-1749090202328	Re: 05.06	че?	mailuser@mail.devsanya.ru	t	2025-06-05 05:56:19.539655+03	f	\N	qwe@qwe.ru
177	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Ответ по вашей заявке 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Здравствуйте, qweqwe!\n\nСотрудник техподдержки (Техподдержка ИНТ, mailuser@mail.devsanya.ru) ответил на вашу заявку #20250605052322708650:\n\nче?\n\n---\nВы можете ответить на это письмо или перейти в личный кабинет на сайте.\nС уважением,\nТехподдержка ИНТ	devsanya.ru	t	2025-06-05 05:56:19.596878+03	f	\N	\N
178	ticket-20250605052322708650-1749090202328	Re: 05.06	п	mailuser@mail.devsanya.ru	t	2025-06-05 05:57:42.220797+03	f	\N	qwe@qwe.ru
179	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Ответ по вашей заявке 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Здравствуйте, qweqwe!\n\nСотрудник техподдержки (Техподдержка ИНТ, mailuser@mail.devsanya.ru) ответил на вашу заявку #20250605052322708650:\n\nп\n\n---\nВы можете ответить на это письмо или перейти в личный кабинет на сайте.\nС уважением,\nТехподдержка ИНТ	devsanya.ru	t	2025-06-05 05:57:42.346537+03	f	\N	\N
180	ticket-20250605052322708650-1749090202328	Re: 05.06	ек	mailuser@mail.devsanya.ru	t	2025-06-05 05:59:05.859736+03	f	\N	qwe@qwe.ru
181	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Ответ по вашей заявке 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Здравствуйте, qweqwe!\n\nСотрудник техподдержки (Техподдержка ИНТ, mailuser@mail.devsanya.ru) ответил на вашу заявку #20250605052322708650:\n\nек\n\n---\nВы можете ответить на это письмо или перейти в личный кабинет на сайте.\nС уважением,\nТехподдержка ИНТ	devsanya.ru	t	2025-06-05 05:59:05.932465+03	f	\N	\N
182	ticket-20250605052322708650-1749090202328	Re: 05.06	цуке	mailuser@mail.devsanya.ru	t	2025-06-05 06:01:36.61574+03	f	\N	qwe@qwe.ru
183	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Ответ по вашей заявке 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Здравствуйте, qweqwe!\n\nСотрудник техподдержки (Техподдержка ИНТ, mailuser@mail.devsanya.ru) ответил на вашу заявку #20250605052322708650:\n\nцуке\n\n---\nВы можете ответить на это письмо или перейти в личный кабинет на сайте.\nС уважением,\nТехподдержка ИНТ	devsanya.ru	t	2025-06-05 06:01:36.732196+03	f	\N	\N
184	ticket-20250605052322708650-1749090202328	Re: 05.06	с файлом	mailuser@mail.devsanya.ru	t	2025-06-05 07:21:40.059223+03	f	\N	qwe@qwe.ru
185	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650: Ответ по вашей заявке 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Здравствуйте, qweqwe!\n\nСотрудник техподдержки (Техподдержка ИНТ, mailuser@mail.devsanya.ru) ответил на вашу заявку #20250605052322708650:\n\nс файлом\n\n---\nВы можете ответить на это письмо или перейти в личный кабинет на сайте.\nС уважением,\nТехподдержка ИНТ	devsanya.ru	t	2025-06-05 07:21:40.239479+03	f	\N	\N
186	ticket-20250605052322708650-1749090202328	Re: 05.06 [ticket-20250605052322708650-1749090202328]	и я с файлом	qwe@qwe.ru	f	2025-06-05 07:22:14.112033+03	f	11	\N
187	ticket-20250605052322708650-1749090202328	Re: Заявка #20250605052322708650: 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250605052322708650:\n\nи я с файлом	devsanya.ru	t	2025-06-05 07:22:14.31077+03	f	\N	\N
188	ticket-20250605052322708650-1749090202328	Re: 05.06 [ticket-20250605052322708650-1749090202328]	tt	qwe@qwe.ru	f	2025-06-06 05:18:45.710449+03	f	11	\N
189	ticket-20250605052322708650-1749090202328	Re: Заявка #20250605052322708650: 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Пользователь qweqwe (qwe@qwe.ru) добавил новое сообщение в заявку #20250605052322708650:\n\ntt	devsanya.ru	t	2025-06-06 05:18:45.865751+03	f	\N	\N
190	ticket-20250605052322708650-1749090202328	Заявка #20250605052322708650 закрыта пользователем: 05.06 [Thread#ticket-20250605052322708650-1749090202328]	Пользователь qweqwe (qwe@qwe.ru) закрыл заявку #20250605052322708650.	devsanya.ru	t	2025-06-06 07:45:50.611836+03	f	\N	\N
\.


--
-- Data for Name: ticket_attachments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket_attachments (id, message_id, file_name, file_path, file_size, mime_type, created_at) FROM stdin;
1	4	28e82249f1cc097869dd783b0e4e36d0.docx	uploads\\attachments-1746588740188-367369220.docx	52534	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-07 06:32:20.790181+03
2	6	28e82249f1cc097869dd783b0e4e36d0.docx	uploads\\attachments-1746589426643-387191705.docx	52534	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-07 06:43:46.851226+03
3	14	28e82249f1cc097869dd783b0e4e36d0.docx	uploads\\attachments-1746591927675-789043681.docx	52534	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-07 07:25:27.809804+03
4	29	ÐÐÐÐÐ.docx	uploads/attachments-1747192081291-928579923.docx	70259	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-14 06:08:01.325514+03
5	30	Ð²Ð²ÐµÐ´ÐµÐ½Ð¸Ðµ Ð² ÑÐ¿ÐµÑÐ¸Ð°Ð»ÑÐ½Ð¾ÑÑÑ.docx	uploads/attachments-1747192095891-823697399.docx	11543	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-14 06:08:15.920294+03
6	30	ÐÐ¾ÐºÑÐ¼ÐµÐ½Ñ Microsoft Office Word.docx	uploads/attachments-1747192095891-190665084.docx	10309	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-14 06:08:15.920294+03
7	31	UML-Ð´Ð¸Ð°Ð³ÑÐ°Ð¼Ð¼Ñ.docx	uploads/attachments-1747192604028-967681691.docx	756281	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-14 06:16:44.0742+03
8	32	UML-Ð´Ð¸Ð°Ð³ÑÐ°Ð¼Ð¼Ñ.docx	uploads/attachments-1747192690493-166815611.docx	756281	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-14 06:18:10.531893+03
9	33	ÐÐ²Ð¸ÑÐ°Ð½ÑÐ¸Ñ ÐÐ°ÑÐ¿Ð¾ÑÑ Ð Ð¤.docx	uploads/attachments-1747194107928-489097341.docx	36073	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-14 06:41:47.965318+03
10	47	Ð¢ÐµÑÑÐ¸ÑÐ¾Ð²Ð°Ð½Ð¸Ðµ ÑÐ°Ð¹ÑÐ°.docx	uploads/attachments-1747370867017-954887861.docx	15682	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-16 07:47:47.088418+03
11	70	ModuleS7forIntegritySCADA_v7.docx	uploads/attachments-1747377248904-775863802.docx	313167	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-16 09:34:08.97565+03
12	80	Ð¢ÐµÑÑ.docx	uploads/attachments-1747552017890-463375296.docx	13300	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-18 10:06:57.922051+03
13	83	task_153201.docx	uploads/attachments-1747618736069-144735516.docx	101107	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-19 04:38:56.13656+03
14	84	a08162bed521a51e7d8b3f21344348c0.pdf	uploads/attachments-1747619345179-932296394.pdf	899120	application/pdf	2025-05-19 04:49:05.21904+03
15	85	Maket_UP.xlsx	uploads/attachments-1747619382284-247815292.xlsx	17082	application/vnd.openxmlformats-officedocument.spreadsheetml.sheet	2025-05-19 04:49:42.312025+03
16	92	1 (1).doc	uploads/attachments-1747705098947-580327897.doc	3774976	application/msword	2025-05-20 04:38:18.980541+03
17	93	9256554.docx	uploads/attachments-1747706351299-199226840.docx	520521	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-20 04:59:11.339644+03
18	94	cisco.docx	uploads/attachments-1747706364877-456621162.docx	18815	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-20 04:59:24.903934+03
19	98	FFF.docx	uploads/attachments-1747727159796-323442218.docx	428148	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-05-20 10:45:59.844928+03
20	100	IntegrityDataViewer.png	uploads/attachments-1748318411622-775493809.png	5366	image/png	2025-05-27 07:00:11.665679+03
21	121	ÐÐÐÐÐ.docx	uploads/attachments-1749097300009-765535599.docx	70259	application/vnd.openxmlformats-officedocument.wordprocessingml.document	2025-06-05 07:21:40.059223+03
22	122	1 (1).doc	uploads/attachments-1749097334046-767242967.doc	3774976	application/msword	2025-06-05 07:22:14.112033+03
\.


--
-- Data for Name: ticket_messages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket_messages (id, ticket_id, message_number, sender_type, sender_id, sender_email, message, created_at, is_read, email_message_id, in_reply_to, email_id) FROM stdin;
1	1	1	user	11	qwe@qwe.ru	te	2025-05-07 06:22:59.333105+03	f	\N	\N	\N
2	2	1	user	11	qwe@qwe.ru	цуке	2025-05-07 06:27:03.115924+03	f	\N	\N	\N
3	3	1	user	11	qwe@qwe.ru	2345	2025-05-07 06:29:47.708907+03	f	\N	\N	\N
4	4	1	user	11	qwe@qwe.ru	wert	2025-05-07 06:32:20.790181+03	f	\N	\N	\N
5	5	1	user	11	qwe@qwe.ru	erty	2025-05-07 06:43:31.136964+03	f	\N	\N	\N
6	6	1	user	11	qwe@qwe.ru	4567	2025-05-07 06:43:46.851226+03	f	\N	\N	\N
7	4	2	user	11	qwe@qwe.ru	dfgh	2025-05-07 06:58:46.268698+03	f	\N	\N	1
8	4	3	user	11	user@example.com	Я проверил настройки, которые вы прислали, но проблема осталась. Можете посмотреть логи?	2025-05-07 07:04:22.554324+03	f	msg-2-ticket-20250507103220030664-1746588740796	\N	2
9	4	4	user	11	qwe@qwe.ru	вап	2025-05-07 07:10:10.829842+03	f	\N	\N	3
10	4	5	user	11	user@example.com	Ответ	2025-05-07 07:10:31.374398+03	f	msg-2-ticket-20250507103220030664-1746588740796	\N	4
11	4	6	support	\N	user@example.com	Ответ2	2025-05-07 07:21:49.31092+03	t	msg-2-ticket-20250507103220030664-1746588740796	\N	5
12	4	7	user	11	qwe@qwe.ru	erty	2025-05-07 07:21:59.654697+03	f	\N	\N	6
13	4	8	support	\N	user@example.com	Ответ3	2025-05-07 07:22:18.295887+03	t	msg-2-ticket-20250507103220030664-1746588740796	\N	7
14	7	1	user	11	qwe@qwe.ru	4567	2025-05-07 07:25:27.809804+03	f	\N	\N	\N
15	7	2	support	\N	user@example.com	Что означает Ваше число?	2025-05-07 07:32:32.473164+03	t	msg-2-ticket-20250507112527823603-1746591927814	\N	8
16	8	1	user	11	qwe@qwe.ru	проверяем	2025-05-07 07:45:38.602886+03	f	\N	\N	\N
17	9	1	user	11	qwe@qwe.ru	07.05test	2025-05-07 07:49:00.98278+03	f	\N	\N	\N
18	10	1	user	11	qwe@qwe.ru	05055	2025-05-07 07:58:53.151612+03	f	\N	\N	\N
19	11	1	user	11	qwe@qwe.ru	05055	2025-05-07 07:59:32.920543+03	f	\N	\N	\N
20	11	2	user	11	qwe@qwe.ru	Здравствуйте, это мой ответ на ваше предыдущее сообщение.\n\nПроблема все еще актуальна. Я перезагрузил компьютер, но это не помогло.\n\nС уважением,\nИван	2025-05-07 08:02:18.420928+03	f	\N	\N	9
21	11	3	support	11	qwe@qwe.ru	Здравствуйте, это мой ответ на ваше предыдущее сообщение.\n\nПроблема все еще актуальна. Я перезагрузил компьютер, но это не помогло.\n\nС уважением,\nИван	2025-05-07 08:04:04.988246+03	t	\N	\N	10
22	12	1	user	11	qwe@qwe.ru	ывап	2025-05-07 08:27:31.900325+03	f	\N	\N	\N
23	13	1	user	11	qwe@qwe.ru	Тест	2025-05-13 05:38:44.548065+03	f	\N	\N	\N
24	14	1	user	11	qwe@qwe.ru	13.05(2)	2025-05-13 06:02:13.073799+03	f	\N	\N	\N
25	15	1	user	11	qwe@qwe.ru	13.05(3)	2025-05-13 07:20:05.99322+03	f	\N	\N	\N
26	16	1	user	11	qwe@qwe.ru	Сообщение 13.05(4)	2025-05-13 10:25:23.011918+03	f	\N	\N	\N
27	17	1	user	11	qwe@qwe.ru	14.05 новая тех.заявка	2025-05-14 04:26:23.027334+03	f	\N	\N	\N
28	18	1	user	11	qwe@qwe.ru	отправка заявки с файлами	2025-05-14 06:06:23.044307+03	f	\N	\N	\N
29	19	1	user	11	qwe@qwe.ru	2345	2025-05-14 06:08:01.325514+03	f	\N	\N	\N
30	20	1	user	11	qwe@qwe.ru	3456	2025-05-14 06:08:15.920294+03	f	\N	\N	\N
31	21	1	user	11	qwe@qwe.ru	н	2025-05-14 06:16:44.0742+03	f	\N	\N	\N
32	22	1	user	11	qwe@qwe.ru	н	2025-05-14 06:18:10.531893+03	f	\N	\N	\N
33	23	1	user	11	qwe@qwe.ru	23	2025-05-14 06:41:47.965318+03	f	\N	\N	\N
34	24	1	user	11	qwe@qwe.ru	j	2025-05-14 09:33:53.470331+03	f	\N	\N	\N
35	25	1	user	12	sanya@s.ru	Упал сервер	2025-05-15 06:00:55.589017+03	f	\N	\N	\N
36	26	1	user	11	qwe@qwe.ru	test	2025-05-15 06:30:12.554333+03	f	\N	\N	\N
37	27	1	user	14	shy@s.ru	1	2025-05-15 07:34:34.546546+03	f	\N	\N	\N
38	28	1	user	15	test@qwe.ru	testqwe	2025-05-15 07:41:57.891096+03	f	\N	\N	\N
39	29	1	user	11	qwe@qwe.ru	Проверка входящих от тех.заявки	2025-05-16 05:10:09.161844+03	f	\N	\N	\N
40	29	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 09:10:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> Проверка входящих от тех.заявки\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516051009385554\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516051009385554-1747361409200\r\nШлем входящее, прием?	2025-05-16 05:13:06.985746+03	f	\N	\N	36
41	26	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-15 10:30:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 15.05\r\n> \r\n> Сообщение:\r\n> \r\n> test\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250515063012196187\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250515063012196187-1747279812565\r\nОтвет на вашу заявку "test"	2025-05-16 05:13:57.929262+03	f	\N	\N	38
42	29	3	user	11	qwe@qwe.ru	прием!	2025-05-16 05:20:19.88735+03	f	\N	\N	40
43	26	3	user	11	qwe@qwe.ru	спасибо	2025-05-16 05:28:05.685832+03	f	\N	\N	42
44	30	1	user	11	qwe@qwe.ru	Проверка на переписку	2025-05-16 07:44:40.433224+03	f	\N	\N	\N
45	30	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 11:44:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> Проверка на переписку\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516074440210456\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516074440210456-1747370680461\r\nОтвечаю на проверку	2025-05-16 07:44:52.771637+03	f	\N	\N	44
46	30	3	user	11	qwe@qwe.ru	Ответ пришел, жду ответ номер 2	2025-05-16 07:45:08.643633+03	f	\N	\N	45
47	31	1	user	11	qwe@qwe.ru	тест сайта	2025-05-16 07:47:47.088418+03	f	\N	\N	\N
48	32	1	user	11	qwe@qwe.ru	1	2025-05-16 07:58:55.27202+03	f	\N	\N	\N
49	32	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 11:58:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05\r\n> \r\n> Сообщение:\r\n> \r\n> 1\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516075855439556\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516075855439556-1747371535307\r\n2	2025-05-16 07:59:01.636487+03	f	\N	\N	47
50	32	3	user	11	qwe@qwe.ru	3	2025-05-16 07:59:12.072233+03	f	\N	\N	49
51	33	1	user	11	qwe@qwe.ru	1	2025-05-16 08:13:50.763154+03	f	\N	\N	\N
78	38	3	user	17	tamara200148@gmail.com	Ересь победит	2025-05-18 10:03:54.838956+03	f	\N	\N	99
52	33	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 12:13:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 1\r\n> \r\n> Сообщение:\r\n> \r\n> 1\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516081350163472\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516081350163472-1747372430792\r\n2	2025-05-16 08:13:58.06819+03	f	\N	\N	52
53	33	3	user	11	qwe@qwe.ru	3	2025-05-16 08:14:03.448935+03	f	\N	\N	54
54	34	1	user	11	qwe@qwe.ru	16.05 12:26	2025-05-16 08:26:46.30186+03	f	\N	\N	\N
55	34	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 12:26:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> 16.05 12:26\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516082646907539\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516082646907539-1747373206318\r\n16.05 12:26 ответ	2025-05-16 08:26:57.926782+03	f	\N	\N	57
56	34	3	user	11	qwe@qwe.ru	16.05 12:26 вопрос 2	2025-05-16 08:27:09.16095+03	f	\N	\N	59
57	34	4	user	11	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> 16.05 12:26 вопрос 2\r\nответ 2	2025-05-16 08:27:25.372639+03	f	\N	\N	61
58	34	5	user	11	qwe@qwe.ru	вопрос 3	2025-05-16 08:27:46.756726+03	f	\N	\N	63
59	34	6	user	11	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 3\r\nответ 3	2025-05-16 08:27:56.242272+03	f	\N	\N	65
60	34	7	user	11	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 12:27:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 3\r\nответ 3	2025-05-16 08:28:00.892734+03	f	\N	\N	67
61	34	8	user	11	qwe@qwe.ru	вопрос 4	2025-05-16 08:42:07.558077+03	f	\N	\N	69
62	34	9	user	11	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 4\r\nответ 4	2025-05-16 08:42:19.200014+03	f	\N	\N	71
63	34	10	user	11	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 4\r\nответ 4	2025-05-16 08:42:24.877312+03	f	\N	\N	73
64	34	11	user	11	qwe@qwe.ru	вопрос 5	2025-05-16 08:42:54.974105+03	f	\N	\N	75
65	34	12	user	11	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 12:42:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516082646907539\r\n> \r\n> Тема: 16.05 12:26\r\n> \r\n> Сообщение:\r\n> \r\n> вопрос 5\r\nответ 5	2025-05-16 08:43:07.828366+03	f	\N	\N	77
66	35	1	user	16	mob@qwe.ru	С телефона	2025-05-16 08:52:00.130192+03	f	\N	\N	\N
67	35	2	user	16	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 12:52:\r\n> Пользователь: undefined (mob@qwe.ru)\r\n> \r\n> Тема: С телефона\r\n> \r\n> Сообщение:\r\n> \r\n> С телефона\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516085200699547\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516085200699547-1747374720134\r\nотвечаю	2025-05-16 08:52:12.713941+03	f	\N	\N	80
68	35	3	user	16	mob@qwe.ru	Отвечаю с телефона	2025-05-16 08:52:27.100295+03	f	\N	\N	82
69	35	4	user	16	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 12:52:\r\n> Пользователь Mob (mob@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516085200699547\r\n> \r\n> Тема: С телефона\r\n> \r\n> Сообщение:\r\n> \r\n> Отвечаю с телефона\r\nотвечаю на ответ с телефона	2025-05-16 08:52:41.32549+03	f	\N	\N	84
70	36	1	user	11	qwe@qwe.ru	423432423423424234	2025-05-16 09:34:08.97565+03	f	\N	\N	\N
71	36	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 13:34:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 23423423423432432\r\n> \r\n> Сообщение:\r\n> \r\n> 423432423423424234\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516093408021423\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516093408021423-1747377248981\r\nДокумент увидел	2025-05-16 09:34:27.356867+03	f	\N	\N	87
72	37	1	user	11	qwe@qwe.ru	14:01	2025-05-16 10:01:16.034533+03	f	\N	\N	\N
73	37	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-16 14:01:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 14:01\r\n> \r\n> Сообщение:\r\n> \r\n> 14:01\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250516100116051682\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250516100116051682-1747378876040\r\nда, сейчас 14:01	2025-05-16 10:01:27.910498+03	f	\N	\N	90
74	37	3	user	11	qwe@qwe.ru	спасибо	2025-05-16 10:01:38.559835+03	f	\N	\N	92
75	37	4	user	11	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-16 14:01:\r\n> Пользователь qweqwe (qwe@qwe.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250516100116051682\r\n> \r\n> Тема: 14:01\r\n> \r\n> Сообщение:\r\n> \r\n> спасибо\r\nпожалуйста	2025-05-16 10:01:46.573446+03	f	\N	\N	94
76	38	1	user	17	tamara200148@gmail.com	Заявка для теста	2025-05-18 10:02:23.050478+03	f	\N	\N	\N
77	38	2	user	17	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-18 14:02:\r\n> Пользователь: undefined (tamara200148@gmail.com)\r\n> \r\n> Тема: Тестовая заявка\r\n> \r\n> Сообщение:\r\n> \r\n> Заявка для теста\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250518100223824219\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250518100223824219-1747551743074\r\nТРИПЛКАААААААААААААААААААААААААААААААААААААААААААААААААААААААА	2025-05-18 10:02:50.491652+03	f	\N	\N	97
79	38	4	user	17	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-18 14:03:\r\n> Пользователь Павлова Тамара\r\n> Махмутовна (tamara200148@gmail.com) добавил\r\n> новое сообщение в заявку:\r\n> \r\n> Номер заявки: 20250518100223824219\r\n> \r\n> Тема: Тестовая заявка\r\n> \r\n> Сообщение:\r\n> \r\n> Ересь победит\r\nи тепя луплюююююююююююююююююююююююююююююю \r\nмаяяяяяяяяяяяяяяяяяяяяяяяяяяяяяя	2025-05-18 10:04:57.347114+03	f	\N	\N	101
80	39	1	user	17	tamara200148@gmail.com	Туц туц туц туц туц	2025-05-18 10:06:57.922051+03	f	\N	\N	\N
81	40	1	user	11	qwe@qwe.ru	19.05	2025-05-19 03:56:26.513152+03	f	\N	\N	\N
82	40	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-19 07:56:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: 19.05\r\n> \r\n> Сообщение:\r\n> \r\n> 19.05\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519035626133908\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519035626133908-1747616186529\r\ntt	2025-05-19 03:57:00.978513+03	f	\N	\N	107
83	41	1	user	11	qwe@qwe.ru	1	2025-05-19 04:38:56.13656+03	f	\N	\N	\N
84	42	1	user	11	qwe@qwe.ru	pdf	2025-05-19 04:49:05.21904+03	f	\N	\N	\N
85	43	1	user	11	qwe@qwe.ru	txt	2025-05-19 04:49:42.312025+03	f	\N	\N	\N
86	43	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\ntxtxtx	2025-05-19 04:53:54.06763+03	f	\N	\N	112
87	43	3	user	11	mailuser <mailuser@mail.devsanya.ru>	--=_1bdef548719f9061c1e1404e2b30705a\r\nContent-Transfer-Encoding: 8bit\r\nContent-Type: text/plain; charset=UTF-8;\r\n format=flowed\r\n\r\nundefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\n\r\n--=_1bdef548719f9061c1e1404e2b30705a\r\nContent-Transfer-Encoding: base64\r\nContent-Type: application/vnd.openxmlformats-officedocument.wordprocessingml.document;\r\n name="=?UTF-8?Q?=D1=83=D1=87=D0=B5=D0=B1=D0=BD=D1=8B=D0=B9_=D0=BE=D1=82?=\r\n =?UTF-8?Q?=D0=BF=D1=83=D1=81=D0=BA=2Edocx?="\r\nContent-Disposition: attachment;\r\n filename*0*=UTF-8''%D1%83%D1%87%D0%B5%D0%B1%D0%BD%D1%8B%D0%B9%20%D0%BE%D1;\r\n filename*1*=%82%D0%BF%D1%83%D1%81%D0%BA.docx;\r\n size=13766\r\n\r\nUEsDBBQABgAIAAAAIQD4K3FghQEAAI4FAAATAAgCW0NvbnRlbnRfVHlwZXNdLnhtbCCiBAIooAAC\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC0\r\nVMtOwzAQvCPxD5GvKHHLASHUtAcoR6hEEWdjb1qLxLa87uvv2SRtVKBNKgqXSI69M7Mzaw9G6yKP\r\nluBRW5OyftJjERhplTazlL1OH+NbFmEQRoncGkjZBpCNhpcXg+nGAUZUbTBl8xDcHeco51AITKwD\r\nQzuZ9YUItPQz7oT8EDPg173eDZfWBDAhDiUGGw4eIBOLPETjNf2ulXjIkUX39cGSK2XCuVxLEUgp\r\nXxr1jSXeMiRUWZ3BuXZ4RTIYP8hQ7hwn2NY9kzVeK4gmwocnUZAMvrJecWXloqAeknaYAzptlmkJ\r\nTX2J5ryVgEieF3nS7BRCm53+ozowbHLAv1dR47bRk86Jtw455XI2P5TJK1AxWeHABw1NdB2tv+kw\r\nH2cZSBq07iwKjEvDk7q9vdq2TqvAEUKggE4h+Tr+cVfgO+ROCYFuF/Dq2z+h13YZFUwnZUYXcCre\r\nczib78ecN9CdIlbw/vJv7u+Btwlppl1a/wszdo9TWX1gxnn1mg4/AQAA//8DAFBLAwQUAAYACAAA\r\nACEAHpEat/MAAABOAgAACwAIAl9yZWxzLy5yZWxzIKIEAiigAAIAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\r\nAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIyS20oDQQyG7wXfYch9N9sKItLZ\r\n3kihdyLrA4SZ7AF3Dsyk2r69oyC6UNte5vTny0/Wm4Ob1DunPAavYVnVoNibYEffa3htt4sHUFnI\r\nW5qCZw1HzrBpbm/WLzyRlKE8jDGrouKzhkEkPiJmM7CjXIXIvlS6kBxJCVOPkcwb9Yyrur7H9FcD\r\nmpmm2lkNaWfvQLXHWDZf1g5dNxp+Cmbv2MuJFcgHYW/ZLmIqbEnGco1qKfUsGmwwzyWdkWKsCjbg\r\naaLV9UT/X4uOhSwJoQmJz/N8dZwDWl4PdNmiecevOx8hWSwWfXv7Q4OzL2g+AQAA//8DAFBLAwQU\r\nAAYACAAAACEAU1ivTyUBAAC5AwAAHAAIAXdvcmQvX3JlbHMvZG9jdW1lbnQueG1sLnJlbHMgogQB\r\n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\r\nY3RzLnhtbFBLBQYAAAAADAAMAAkDAACnMgAAAAA=\r\n--=_1bdef548719f9061c1e1404e2b30705a--\r\n	2025-05-19 05:00:50.473529+03	f	\N	\N	114
88	42	2	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: pdf\r\n> \r\n> Сообщение:\r\n> \r\n> pdf\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044905206402\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044905206402-1747619345224\r\n111	2025-05-19 08:15:41.311666+03	f	\N	\N	117
89	43	4	user	11	mailuser <mailuser@mail.devsanya.ru>	undefined писал 2025-05-19 08:49:\r\n> Пользователь: undefined (qwe@qwe.ru)\r\n> \r\n> Тема: txt\r\n> \r\n> Сообщение:\r\n> \r\n> txt\r\n> -------------------------\r\n> \r\n> Идентификатор заявки: 20250519044942465318\r\n> \r\n> Идентификатор треда (для ответов):\r\n> ticket-20250519044942465318-1747619382318\r\n	2025-05-19 08:22:27.361831+03	f	\N	\N	119
90	44	1	user	11	qwe@qwe.ru	цуке	2025-05-19 10:17:16.23968+03	f	\N	\N	\N
91	44	2	user	11	qwe@qwe.ru	asfd	2025-05-20 04:27:35.531371+03	f	\N	\N	122
92	44	3	user	11	qwe@qwe.ru	ййй	2025-05-20 04:38:18.980541+03	f	\N	\N	124
93	45	1	user	22	b@b.ru	qwer	2025-05-20 04:59:11.339644+03	f	\N	\N	\N
94	45	2	user	22	b@b.ru	rrrr	2025-05-20 04:59:24.903934+03	f	\N	\N	127
95	45	3	user	22	mailuser <mailuser@mail.devsanya.ru>	Ваш Сайт ИНТ писал 2025-05-20 08:59:\r\n> Пользователь BIO (b@b.ru) добавил новое\r\n> сообщение в заявку:\r\n> \r\n> Номер заявки: 20250520045911858996\r\n> \r\n> Тема: qwe\r\n> \r\n> Сообщение:\r\n> \r\n> rrrr\r\nok file	2025-05-20 04:59:40.883992+03	f	\N	\N	129
96	46	1	user	11	qwe@qwe.ru	aga	2025-05-20 06:36:36.108242+03	f	\N	\N	\N
97	47	1	user	11	qwe@qwe.ru	Упал вчера	2025-05-20 09:50:25.756751+03	f	\N	\N	\N
98	47	2	user	11	qwe@qwe.ru	sdfg	2025-05-20 10:45:59.844928+03	f	\N	\N	133
99	45	4	user	22	b@b.ru	wrt	2025-05-23 06:47:47.089842+03	f	\N	\N	135
100	48	1	user	26	a@mail.ru	Все пропало	2025-05-27 07:00:11.665679+03	f	\N	\N	\N
101	49	1	user	26	a@mail.ru	аываываываыва	2025-05-27 07:00:52.36405+03	f	\N	\N	\N
102	50	1	user	27	acompany@qwe.ru	Пишу с компании Компания	2025-05-28 05:56:12.056482+03	f	\N	\N	\N
103	51	1	user	27	acompany@qwe.ru	тест закрытая фильтр	2025-05-28 07:30:59.697755+03	f	\N	\N	\N
104	52	1	user	11	qwe@qwe.ru	цукцук	2025-05-28 08:14:07.902866+03	f	\N	\N	\N
105	53	1	user	11	qwe@qwe.ru	Как использовать сертификаты безопасности при настройке удаленного подключения в IntegritDataTransport	2025-05-28 08:15:26.666486+03	f	\N	\N	\N
106	54	1	user	11	qwe@qwe.ru	Какой полный перечень параметров у функции Application.Execute в IntegrityHMI	2025-05-28 08:17:34.719194+03	f	\N	\N	\N
107	55	1	user	11	qwe@qwe.ru	Поддерживается ли работа по протоколу S7 с контроллерами Siemens 1500 серии?	2025-05-28 08:19:56.599138+03	f	\N	\N	\N
108	56	1	user	11	qwe@qwe.ru	Укажите полный перечень поддерживаемых систем конкретизации для IntegritySCADA	2025-05-28 08:21:18.652713+03	f	\N	\N	\N
109	57	1	user	11	qwe@qwe.ru	Как перенести лицензии с одной машины на другую?	2025-05-28 08:22:13.922465+03	f	\N	\N	\N
110	58	1	user	11	qwe@qwe.ru	Возможно ли доработать события, чтобы они проигрывали звуки в порядке приоритета с дополнительной	2025-05-28 08:24:07.342574+03	f	\N	\N	\N
111	59	1	user	11	qwe@qwe.ru	qwe	2025-05-29 06:04:17.781821+03	f	\N	\N	\N
112	60	1	user	11	qwe@qwe.ru	Проверка связи	2025-06-05 05:23:22.31044+03	f	\N	\N	\N
113	60	2	support	\N	mailuser@mail.devsanya.ru	Ответ	2025-06-05 05:53:39.817816+03	t	\N	\N	168
114	60	3	user	11	qwe@qwe.ru	че ответ?	2025-06-05 05:53:57.201558+03	f	\N	\N	170
115	60	4	support	\N	mailuser@mail.devsanya.ru	а че?	2025-06-05 05:54:08.066585+03	t	\N	\N	172
116	60	5	user	11	qwe@qwe.ru	rty	2025-06-05 05:56:05.240579+03	f	\N	\N	174
117	60	6	support	\N	mailuser@mail.devsanya.ru	че?	2025-06-05 05:56:19.539655+03	t	\N	\N	176
118	60	7	support	\N	mailuser@mail.devsanya.ru	п	2025-06-05 05:57:42.220797+03	t	\N	\N	178
119	60	8	support	\N	mailuser@mail.devsanya.ru	ек	2025-06-05 05:59:05.859736+03	t	\N	\N	180
120	60	9	support	\N	mailuser@mail.devsanya.ru	цуке	2025-06-05 06:01:36.61574+03	t	\N	\N	182
121	60	10	support	\N	mailuser@mail.devsanya.ru	с файлом	2025-06-05 07:21:40.059223+03	t	\N	\N	184
122	60	11	user	11	qwe@qwe.ru	и я с файлом	2025-06-05 07:22:14.112033+03	f	\N	\N	186
123	60	12	user	11	qwe@qwe.ru	tt	2025-06-06 05:18:45.710449+03	f	\N	\N	188
\.


--
-- Data for Name: ticket_statuses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket_statuses (id, name, description) FROM stdin;
1	open	Открытая заявка, ожидает ответа от техподдержки
2	in_progress	Заявка в работе у техподдержки
3	waiting_for_user	Ожидается ответ от пользователя
4	closed	Заявка закрыта
\.


--
-- Data for Name: tickets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tickets (id, ticket_number, user_id, subject, status_id, created_at, updated_at, closed_at, email_thread_id) FROM stdin;
1	20250507102259570872	11	te	1	2025-05-07 06:22:59.333105+03	2025-05-07 06:22:59.333105+03	\N	ticket-20250507102259570872-1746588179340
6	20250507104346663040	11	4657	4	2025-05-07 06:43:46.851226+03	2025-05-07 06:51:40.903861+03	2025-05-07 06:51:40.903861+03	ticket-20250507104346663040-1746589426857
5	20250507104331049457	11	erty	4	2025-05-07 06:43:31.136964+03	2025-05-07 06:52:27.594575+03	2025-05-07 06:52:27.594575+03	ticket-20250507104331049457-1746589411140
4	20250507103220030664	11	tew	3	2025-05-07 06:32:20.790181+03	2025-05-07 07:22:18.295887+03	\N	ticket-20250507103220030664-1746588740796
7	20250507112527823603	11	4657	3	2025-05-07 07:25:27.809804+03	2025-05-07 07:32:32.473164+03	\N	ticket-20250507112527823603-1746591927814
8	20250507114538815280	11	07.05	1	2025-05-07 07:45:38.602886+03	2025-05-07 07:45:38.602886+03	\N	ticket-20250507114538815280-1746593138658
9	20250507114900910483	11	07.05test	1	2025-05-07 07:49:00.98278+03	2025-05-07 07:49:00.98278+03	\N	ticket-20250507114900910483-1746593340989
10	20250507115853924286	11	05055	1	2025-05-07 07:58:53.151612+03	2025-05-07 07:58:53.151612+03	\N	ticket-20250507115853924286-1746593933158
11	20250507115932294093	11	05055	3	2025-05-07 07:59:32.920543+03	2025-05-07 08:04:04.988246+03	\N	ticket-20250507115932294093-1746593973012
12	20250507122731085303	11	ывп	1	2025-05-07 08:27:31.900325+03	2025-05-07 08:27:31.900325+03	\N	ticket-20250507122731085303-1746595651940
15	20250513072005451354	11	13.05(3)	1	2025-05-13 07:20:05.99322+03	2025-05-13 07:20:05.99322+03	\N	ticket-20250513072005451354-1747110005999
16	20250513102523318195	11	Тема13.05(4)	1	2025-05-13 10:25:23.011918+03	2025-05-13 10:25:23.011918+03	\N	ticket-20250513102523318195-1747121123024
17	20250514042623782792	11	14.05	1	2025-05-14 04:26:23.027334+03	2025-05-14 04:26:23.027334+03	\N	ticket-20250514042623782792-1747185983051
19	20250514060801054493	11	2345	1	2025-05-14 06:08:01.325514+03	2025-05-14 06:08:01.325514+03	\N	ticket-20250514060801054493-1747192081334
21	20250514061644723995	11	н	1	2025-05-14 06:16:44.0742+03	2025-05-14 06:16:44.0742+03	\N	ticket-20250514061644723995-1747192604088
22	20250514061810945637	11	н	1	2025-05-14 06:18:10.531893+03	2025-05-14 06:18:10.531893+03	\N	ticket-20250514061810945637-1747192690539
3	20250507102947967730	11	2345	4	2025-05-07 06:29:47.708907+03	2025-05-14 06:20:21.848748+03	2025-05-14 06:20:21.848748+03	ticket-20250507102947967730-1746588587715
13	20250513053844491229	11	13.05	4	2025-05-13 05:38:44.548065+03	2025-05-14 06:20:29.573811+03	2025-05-14 06:20:29.573811+03	ticket-20250513053844491229-1747103924565
2	20250507102703694721	11	цуке	4	2025-05-07 06:27:03.115924+03	2025-05-14 06:20:39.13702+03	2025-05-14 06:20:39.13702+03	ticket-20250507102703694721-1746588423120
20	20250514060815220738	11	3456	4	2025-05-14 06:08:15.920294+03	2025-05-14 06:28:47.599055+03	2025-05-14 06:28:47.599055+03	ticket-20250514060815220738-1747192095924
23	20250514064147239387	11	23	1	2025-05-14 06:41:47.965318+03	2025-05-14 06:41:47.965318+03	\N	ticket-20250514064147239387-1747194107972
14	20250513060213184409	11	13.05(2)	4	2025-05-13 06:02:13.073799+03	2025-05-14 06:51:59.518026+03	2025-05-14 06:51:59.518026+03	ticket-20250513060213184409-1747105333078
18	20250514060623249172	11	14.05 с файлами	4	2025-05-14 06:06:23.044307+03	2025-05-14 06:52:02.843185+03	2025-05-14 06:52:02.843185+03	ticket-20250514060623249172-1747191983067
24	20250514093353075965	11	j	4	2025-05-14 09:33:53.470331+03	2025-05-14 09:33:59.009917+03	2025-05-14 09:33:59.009917+03	ticket-20250514093353075965-1747204433481
25	20250515060055202631	12	server_sanya	1	2025-05-15 06:00:55.589017+03	2025-05-15 06:00:55.589017+03	\N	ticket-20250515060055202631-1747278055615
27	20250515073434829527	14	1	1	2025-05-15 07:34:34.546546+03	2025-05-15 07:34:34.546546+03	\N	ticket-20250515073434829527-1747283674554
28	20250515074157031448	15	testqwe	1	2025-05-15 07:41:57.891096+03	2025-05-15 07:41:57.891096+03	\N	ticket-20250515074157031448-1747284117897
35	20250516085200699547	16	С телефона	1	2025-05-16 08:52:00.130192+03	2025-05-16 08:52:41.32549+03	\N	ticket-20250516085200699547-1747374720134
33	20250516081350163472	11	1	1	2025-05-16 08:13:50.763154+03	2025-05-16 08:14:03.448935+03	\N	ticket-20250516081350163472-1747372430792
29	20250516051009385554	11	16.05	1	2025-05-16 05:10:09.161844+03	2025-05-16 05:20:19.88735+03	\N	ticket-20250516051009385554-1747361409200
26	20250515063012196187	11	15.05	1	2025-05-15 06:30:12.554333+03	2025-05-16 05:28:05.685832+03	\N	ticket-20250515063012196187-1747279812565
30	20250516074440210456	11	16.05	1	2025-05-16 07:44:40.433224+03	2025-05-16 07:45:08.643633+03	\N	ticket-20250516074440210456-1747370680461
31	20250516074747796771	11	тест сайта	1	2025-05-16 07:47:47.088418+03	2025-05-16 07:47:47.088418+03	\N	ticket-20250516074747796771-1747370867102
32	20250516075855439556	11	16.05	1	2025-05-16 07:58:55.27202+03	2025-05-16 07:59:12.072233+03	\N	ticket-20250516075855439556-1747371535307
36	20250516093408021423	11	23423423423432432	1	2025-05-16 09:34:08.97565+03	2025-05-16 09:34:27.356867+03	\N	ticket-20250516093408021423-1747377248981
40	20250519035626133908	11	19.05	1	2025-05-19 03:56:26.513152+03	2025-05-19 03:57:00.978513+03	\N	ticket-20250519035626133908-1747616186529
37	20250516100116051682	11	14:01	1	2025-05-16 10:01:16.034533+03	2025-05-16 10:01:46.573446+03	\N	ticket-20250516100116051682-1747378876040
41	20250519043856610111	11	1	1	2025-05-19 04:38:56.13656+03	2025-05-19 04:38:56.13656+03	\N	ticket-20250519043856610111-1747618736142
34	20250516082646907539	11	16.05 12:26	1	2025-05-16 08:26:46.30186+03	2025-05-16 08:43:07.828366+03	\N	ticket-20250516082646907539-1747373206318
39	20250518100657069589	17	Моя заявка номер 2	1	2025-05-18 10:06:57.922051+03	2025-05-18 10:06:57.922051+03	\N	ticket-20250518100657069589-1747552017927
38	20250518100223824219	17	Тестовая заявка	1	2025-05-18 10:02:23.050478+03	2025-05-18 10:07:35.790007+03	\N	ticket-20250518100223824219-1747551743074
44	20250519101716014185	11	цуе	1	2025-05-19 10:17:16.23968+03	2025-05-20 04:38:18.980541+03	\N	ticket-20250519101716014185-1747639036246
42	20250519044905206402	11	pdf	1	2025-05-19 04:49:05.21904+03	2025-05-19 08:15:41.311666+03	\N	ticket-20250519044905206402-1747619345224
43	20250519044942465318	11	txt	4	2025-05-19 04:49:42.312025+03	2025-05-19 08:22:27.361831+03	2025-05-19 05:02:50.246189+03	ticket-20250519044942465318-1747619382318
50	20250528055612430979	27	С той же компании	1	2025-05-28 05:56:12.056482+03	2025-05-28 05:56:12.056482+03	\N	ticket-20250528055612430979-1748400972076
48	20250527070011894328	26	Пиздец серверу истории	1	2025-05-27 07:00:11.665679+03	2025-05-27 07:00:11.665679+03	\N	ticket-20250527070011894328-1748318411681
46	20250520063636138033	11	aga	1	2025-05-20 06:36:36.108242+03	2025-05-20 06:36:36.108242+03	\N	ticket-20250520063636138033-1747712196113
45	20250520045911858996	22	qwe	1	2025-05-20 04:59:11.339644+03	2025-05-23 06:47:47.089842+03	\N	ticket-20250520045911858996-1747706351359
49	20250527070052079726	26	цуеапукываываыв	1	2025-05-27 07:00:52.36405+03	2025-05-27 07:19:08.736069+03	\N	ticket-20250527070052079726-1748318452367
47	20250520095025584024	11	Сервер Историй	4	2025-05-20 09:50:25.756751+03	2025-05-27 08:08:27.128487+03	2025-05-27 08:08:27.128487+03	ticket-20250520095025584024-1747723825783
51	20250528073059042172	27	тест закрытая фильтр	4	2025-05-28 07:30:59.697755+03	2025-05-28 07:32:46.825603+03	2025-05-28 07:32:46.825603+03	ticket-20250528073059042172-1748406659709
52	20250528081407007870	11	Вопрос по созданию нестандартной динамики	1	2025-05-28 08:14:07.902866+03	2025-05-28 08:14:07.902866+03	\N	ticket-20250528081407007870-1748409247909
58	20250528082407504967	11	Возможно ли доработать события?	1	2025-05-28 08:24:07.342574+03	2025-05-28 08:24:07.342574+03	\N	ticket-20250528082407504967-1748409847348
53	20250528081526983290	11	Серитифкаты безопасности	4	2025-05-28 08:15:26.666486+03	2025-05-28 09:01:29.501484+03	2025-05-28 09:01:29.501484+03	ticket-20250528081526983290-1748409326671
54	20250528081734440902	11	Функция Application.Execute	4	2025-05-28 08:17:34.719194+03	2025-05-28 09:01:35.935172+03	2025-05-28 09:01:35.935172+03	ticket-20250528081734440902-1748409454725
55	20250528081956653103	11	Поддержка S7	4	2025-05-28 08:19:56.599138+03	2025-05-28 09:01:38.725413+03	2025-05-28 09:01:38.725413+03	ticket-20250528081956653103-1748409596604
56	20250528082118579644	11	Поддержка контейнеризации	4	2025-05-28 08:21:18.652713+03	2025-05-28 09:01:41.550059+03	2025-05-28 09:01:41.550059+03	ticket-20250528082118579644-1748409678657
57	20250528082213940287	11	Перенос лицензий	4	2025-05-28 08:22:13.922465+03	2025-05-28 09:01:45.612514+03	2025-05-28 09:01:45.612514+03	ticket-20250528082213940287-1748409733928
59	20250529060417207845	11	qwe	1	2025-05-29 06:04:17.781821+03	2025-05-29 06:04:17.781821+03	\N	ticket-20250529060417207845-1748487857809
60	20250605052322708650	11	05.06	4	2025-06-05 05:23:22.31044+03	2025-06-06 07:45:50.484113+03	2025-06-06 07:45:50.484113+03	ticket-20250605052322708650-1749090202328
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, fio, password_hash, "position", company, activity_sphere, city, phone, created_at, updated_at, account_status) FROM stdin;
1	r	r	gf	yt	hg	yt	ytyt	y	2025-04-22 06:57:22.166079+03	2025-05-29 06:13:59.208743+03	active
2	1	2	3	4	5	6	7	8	2025-04-23 05:00:18.057952+03	2025-05-29 06:13:59.208743+03	active
4	a@a	s	$2b$10$IauITl5E2dhv3oXonqNHHeDrYoUtnAti.lCB.vJfLUlxoItMZE2M2	a	a	a	a	43535	2025-04-23 05:32:13.955303+03	2025-05-29 06:13:59.208743+03	active
5	test.user2@example.com	Тестов Тест Тестович	$2b$10$0Vyc8KHZ.C0n1cxEWXgUxO/UOyOt243X42PQehftf6BcvkTWDbDWy	Тестировщик	ООО Тест Инк.	IT / Тестирование	Тестбург	+79001234567	2025-04-23 05:46:03.927106+03	2025-05-29 06:13:59.208743+03	active
6	test.user3@example.com	Тестов Тест Тестович	$2b$12$envNjeXPql/qmqCQNMSEtuDj0l/JkThpdHCmcRWdwC57IcrwvryUi	Тестировщик	ООО Тест Инк.	IT / Тестирование	Тестбург	+79001234567	2025-04-23 06:58:38.558489+03	2025-05-29 06:13:59.208743+03	active
7	test.user4@example.com	Тестов Тест Тестович	$2b$12$ypp42jWuishKoFYUXSy3u.nqvmOm50zsl.w8DA6z.dYsbTKCWes/e	Тестировщик	ООО Тест Инк.	IT / Тестирование	Тестбург	+79001234567	2025-04-23 07:00:31.756285+03	2025-05-29 06:13:59.208743+03	active
9	test.user5@example.com	a	$2b$12$MMTUeHIFZvlaXYJxxVDrguQPm0.2VjUumAT9baogBOCMZatOXsEhW	a	a	a	a	234124	2025-04-23 07:01:02.007008+03	2025-05-29 06:13:59.208743+03	active
3	test.user1@example.com	123тов Тест Тестович	$2b$10$S505T0W11BlH/XGUp2.oueGYhAzaOTvXyfR/6CiuabGauzJ.9IoxW	Тестировщик	ООО Тест Инк.	IT / Тестирование	Тестбург	+79001234567	2025-04-23 05:23:48.720463+03	2025-05-29 06:13:59.208743+03	active
11	qwe@qwe.ru	qweqwe	$2b$12$mLmZAaZtBdisDCzPpbeJhOSJDfVOFYTI/2IEQi54g7b6tx47OB6aW	asdf	wert	adsf	adsf	asdf	2025-05-07 04:26:57.864072+03	2025-05-29 06:13:59.208743+03	active
12	sanya@s.ru	s	$2b$12$iYDkLdXgzM24rxhgkC6WW.bYnjy1MtmyNUC/D.ijOaowfKl9tuFCS	a	a	a	a	88005553535	2025-05-15 04:47:32.420673+03	2025-05-29 06:13:59.208743+03	active
14	shy@s.ru	a	$2b$12$dBaUnu0Wd/yW.AEZMNajpe/Oe2kvHmUW7W67M2L7QvDR6uALO.NHC	a	a	a	a	555	2025-05-15 07:34:12.744703+03	2025-05-29 06:13:59.208743+03	active
15	test@qwe.ru	test qwe	$2b$12$/t0CbQ9xPg.uGz.FjlBMxOvMDmedWnIJMdPEkWenzIWi19XBfcQdq	n	n	n	n	88	2025-05-15 07:41:40.819985+03	2025-05-29 06:13:59.208743+03	active
16	mob@qwe.ru	Mob	$2b$12$hVVGEk7vgsiHq65Z/lfRsu/k5d9f.iMdktUmQUET7CYnxoRwTVHhm	N	N	N	N	8	2025-05-16 08:51:15.067042+03	2025-05-29 06:13:59.208743+03	active
17	tamara200148@gmail.com	Павлова Тамара Махмутовна	$2b$12$.B3yP3Jzg3jAxBdvaVGL.O8sOda1.VGZCwWFpwqhtsSO198uQtg.K	Преподаватель	СПК	Преподавание	Северск	89627788313	2025-05-18 10:00:08.351124+03	2025-05-29 06:13:59.208743+03	active
18	e@qwe.ru	ФИО	$2b$12$8OOQcgLJpewM4I8emoSyoO1Pz6NZ.OC05iTOe.HoRjtJJ7BtUTgDC	Должность	Компания	Компания	Компания	8800	2025-05-19 03:36:58.25452+03	2025-05-29 06:13:59.208743+03	active
19	text@qwe.ru	Давиденко Саша	$2b$12$2UQAUcBLFkpdcB.1ms8foOIFObu4ORZmpQTYD0TFOKyXCWaNcJT8W	ds	sd	sd	Томск	88005553535	2025-05-19 05:14:16.864445+03	2025-05-29 06:13:59.208743+03	active
20	aa@a.ru	a	$2b$12$y4/onVtrWOGnd/Bd71pYpug0.9DMR1.CnTOEThmNhdA4cOxo3m.BS	a	a	a	a	88005553535	2025-05-19 05:23:06.226358+03	2025-05-29 06:13:59.208743+03	active
21	asd@a.ru	asdf	$2b$12$RL8nUsp99wcrGqMivnVLDepYCIw8nXmE/g.yDs.7YBA1ITQWjUh8G	asd	asdf	adsf	adsf	asdf	2025-05-19 05:25:17.280735+03	2025-05-29 06:13:59.208743+03	active
22	b@b.ru	BIO	$2b$12$iZhIEo/GeikSavHNLFpP6eTvWNmPyH44iXOKf8/7/vaYiYvbKPgvy	a	a	a	a	88005553535	2025-05-20 03:58:09.82972+03	2025-05-29 06:13:59.208743+03	active
23	teat@mail.ru	Иванов Иван Иванович	$2b$12$wEcf8Z65R1h4WkZccLmx7uk6y.XuPtdOhKWSGzv9xArYbxnvD0rcu	Начальник	Компания	Программист	Томск	89230000000	2025-05-20 09:58:11.449302+03	2025-05-29 06:13:59.208743+03	active
24	dva@qwe.ru	А.А.Давиденко	$2b$12$gqdptcb49m.f7uuBDfssFO1bx8HmIVbJBE/IJ4vUyubaCcRJWPKwm	техник	КОмпания	Сфера	Томск	88005553535	2025-05-20 10:07:18.937538+03	2025-05-29 06:13:59.208743+03	active
25	v@v.ru	sdfg	$2b$12$STdKiFYw5Am88XBTwZaZXuKV7zbEbVgEGpAq8blHBs5EuYuj0GckC	a	a	a	a	88	2025-05-21 06:33:58.572685+03	2025-05-29 06:13:59.208743+03	active
26	a@mail.ru	Енот	$2b$12$2b8NDJpU8.BnzRcbkc7mV.wwGwhMf5anTbodxRGLsYGby./K1elHa	Начальник енотов	Компания	Автоматизация	Новосибирск	89234010000	2025-05-27 06:59:19.728304+03	2025-05-29 06:13:59.208743+03	active
27	acompany@qwe.ru	С той же Компании	$2b$12$rGLfwm9UysWX9xMZKnMWIuxzuwqXQZeKQydN4SyeXt2u/HIxpiVGa	D	Компания	СД	Томск	88005553535	2025-05-28 05:55:33.01758+03	2025-05-29 06:13:59.208743+03	active
29	a2@mail.ru	a2	$2b$12$p.04JTm44E1LwUaWWMTPueNcq2/gzAjpDOA.N2R377keIgdu8e4Um	a2	a2	a2	a2	88005553535	2025-05-29 07:09:37.986172+03	2025-05-29 07:34:00.715837+03	active
28	check@mail.ru	ФИО	$2b$12$pClIy.ZQ2GwD7.gW6fbj/O.sdUIwQLODo95d/.L0pQbOQ7R96lxke	Дирик	Комп	Сфера	город	телефон	2025-05-29 06:39:43.908074+03	2025-05-29 07:38:45.597132+03	active
30	tema@mail.ru	f	$2b$12$dldK7ioLDiDc.3Qxs8XuRONn7CITpOkxRzmYjFS.vYyMeTAtVYnTq	a	a	a	a	88005553535	2025-05-29 10:06:44.082425+03	2025-05-29 10:07:17.064231+03	active
31	tri@mail.ru	f	$2b$12$p7tRfbYUb4h9k0JOZ182IexITJ8FOs1jEf.nHTKDBgy5v.Nh5CCZ2	a	a	a	a	88005553535	2025-05-30 08:26:48.46967+03	2025-05-30 08:27:16.05286+03	active
\.


--
-- Data for Name: videos; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.videos (id, title, description, file_path, file_size, thumbnail_path, created_at, updated_at) FROM stdin;
\.


--
-- Name: clients_clients_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.clients_clients_id_seq', 1, true);


--
-- Name: documents_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.documents_id_seq', 3, true);


--
-- Name: emails_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.emails_id_seq', 190, true);


--
-- Name: ticket_attachments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ticket_attachments_id_seq', 22, true);


--
-- Name: ticket_messages_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ticket_messages_id_seq', 123, true);


--
-- Name: ticket_statuses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ticket_statuses_id_seq', 4, true);


--
-- Name: tickets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tickets_id_seq', 60, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 31, true);


--
-- Name: videos_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.videos_id_seq', 1, false);


--
-- Name: clients clients_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.clients
    ADD CONSTRAINT clients_email_key UNIQUE (email);


--
-- Name: documents documents_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.documents
    ADD CONSTRAINT documents_pkey PRIMARY KEY (id);


--
-- Name: emails emails_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emails
    ADD CONSTRAINT emails_pkey PRIMARY KEY (id);


--
-- Name: ticket_attachments ticket_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_attachments
    ADD CONSTRAINT ticket_attachments_pkey PRIMARY KEY (id);


--
-- Name: ticket_messages ticket_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_messages
    ADD CONSTRAINT ticket_messages_pkey PRIMARY KEY (id);


--
-- Name: ticket_statuses ticket_statuses_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_statuses
    ADD CONSTRAINT ticket_statuses_name_key UNIQUE (name);


--
-- Name: ticket_statuses ticket_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_statuses
    ADD CONSTRAINT ticket_statuses_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_pkey PRIMARY KEY (id);


--
-- Name: tickets tickets_ticket_number_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_ticket_number_key UNIQUE (ticket_number);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: videos videos_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.videos
    ADD CONSTRAINT videos_pkey PRIMARY KEY (id);


--
-- Name: idx_emails_thread_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_emails_thread_id ON public.emails USING btree (thread_id);


--
-- Name: idx_emails_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_emails_user_id ON public.emails USING btree (user_id);


--
-- Name: idx_ticket_attachments_message_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ticket_attachments_message_id ON public.ticket_attachments USING btree (message_id);


--
-- Name: idx_ticket_messages_email_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ticket_messages_email_id ON public.ticket_messages USING btree (email_id);


--
-- Name: idx_ticket_messages_sender_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ticket_messages_sender_type ON public.ticket_messages USING btree (sender_type);


--
-- Name: idx_ticket_messages_ticket_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ticket_messages_ticket_id ON public.ticket_messages USING btree (ticket_id);


--
-- Name: idx_tickets_email_thread_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tickets_email_thread_id ON public.tickets USING btree (email_thread_id);


--
-- Name: idx_tickets_status_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tickets_status_id ON public.tickets USING btree (status_id);


--
-- Name: idx_tickets_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_tickets_user_id ON public.tickets USING btree (user_id);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: ticket_messages set_message_number; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_message_number BEFORE INSERT ON public.ticket_messages FOR EACH ROW EXECUTE FUNCTION public.generate_message_number();


--
-- Name: tickets set_ticket_closed_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER set_ticket_closed_at BEFORE INSERT ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.set_initial_closed_at();


--
-- Name: tickets update_ticket_closed_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_ticket_closed_at BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.handle_ticket_closure();


--
-- Name: tickets update_tickets_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_tickets_updated_at BEFORE UPDATE ON public.tickets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: users update_users_updated_at; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: emails emails_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.emails
    ADD CONSTRAINT emails_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ticket_attachments ticket_attachments_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_attachments
    ADD CONSTRAINT ticket_attachments_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.ticket_messages(id) ON DELETE CASCADE;


--
-- Name: ticket_messages ticket_messages_email_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_messages
    ADD CONSTRAINT ticket_messages_email_id_fkey FOREIGN KEY (email_id) REFERENCES public.emails(id) ON DELETE SET NULL;


--
-- Name: ticket_messages ticket_messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_messages
    ADD CONSTRAINT ticket_messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: ticket_messages ticket_messages_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_messages
    ADD CONSTRAINT ticket_messages_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.tickets(id) ON DELETE CASCADE;


--
-- Name: tickets tickets_status_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_status_id_fkey FOREIGN KEY (status_id) REFERENCES public.ticket_statuses(id);


--
-- Name: tickets tickets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tickets
    ADD CONSTRAINT tickets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

