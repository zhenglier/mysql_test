--
-- openGauss database dump
--

SET statement_timeout = 0;
SET xmloption = content;
SET client_encoding = 'SQL_ASCII';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

SET search_path = public;

--
-- Name: operation_status; Type: TYPE; Schema: public; Owner: jxz
--

CREATE TYPE operation_status AS ENUM (
    '运行中',
    '未运行',
    '延迟'
);


ALTER TYPE public.operation_status OWNER TO jxz;

--
-- Name: orders_status; Type: TYPE; Schema: public; Owner: jxz
--

CREATE TYPE orders_status AS ENUM (
    '待支付',
    '已取消',
    '待出行',
    '候补中',
    '已完成'
);


ALTER TYPE public.orders_status OWNER TO jxz;

--
-- Name: passenger_type; Type: TYPE; Schema: public; Owner: jxz
--

CREATE TYPE passenger_type AS ENUM (
    '成人',
    '儿童',
    '学生',
    '残军'
);


ALTER TYPE public.passenger_type OWNER TO jxz;

--
-- Name: seat_status; Type: TYPE; Schema: public; Owner: jxz
--

CREATE TYPE seat_status AS ENUM (
    '空闲',
    '已预订',
    '已占用'
);


ALTER TYPE public.seat_status OWNER TO jxz;

--
-- Name: seat_type; Type: TYPE; Schema: public; Owner: jxz
--

CREATE TYPE seat_type AS ENUM (
    '硬座',
    '软座',
    '硬卧',
    '软卧'
);


ALTER TYPE public.seat_type OWNER TO jxz;

--
-- Name: sex; Type: TYPE; Schema: public; Owner: jxz
--

CREATE TYPE sex AS ENUM (
    '男',
    '女'
);


ALTER TYPE public.sex OWNER TO jxz;

--
-- Name: _navicat_temp_stored_proc(character varying, character varying, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION _navicat_temp_stored_proc(bg character varying, ed character varying, tm timestamp without time zone) RETURNS TABLE(trainid integer, traintype integer, carriagecount integer, departurestation character varying, destinationstation character varying, departuretime time without time zone, arrivaltime time without time zone, duration interval, arrivaldate timestamp without time zone, operationstatus character varying)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$BEGIN
  -- Routine body goes here...
  RETURN QUERY
    SELECT * from traininfo where traininfo.departurestation="bg" and traininfo.destinationstation="ed" and traininfo.arrivaldate="tm";
END
$$;


ALTER FUNCTION public._navicat_temp_stored_proc(bg character varying, ed character varying, tm timestamp without time zone) OWNER TO omm;

--
-- Name: add_passenger(character varying, character varying, character varying, passenger_type); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) RETURNS void
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
	INSERT INTO Passenger (UsersAccount,Id, TelephoneNumber, PassengerType)
	VALUES (users_account,Id,telenum,pt);
END;
$$;


ALTER FUNCTION public.add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) OWNER TO jxz;

--
-- Name: audit_trigger_fn(); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION audit_trigger_fn() RETURNS trigger
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (operation, table_name, record_id, new_data)
        VALUES ('INSERT', TG_TABLE_NAME, NEW.id, row_to_json(NEW)::jsonb);
		ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (operation, table_name, record_id, old_data, new_data)
        VALUES ('UPDATE', TG_TABLE_NAME, NEW.id, row_to_json(OLD)::jsonb, row_to_json(NEW)::jsonb);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.audit_trigger_fn() OWNER TO omm;

--
-- Name: book_seat_and_create_order(character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION book_seat_and_create_order(user_account character varying, p_id character varying, p_train_id character varying, p_start_station_number integer, p_end_station_number integer) RETURNS integer
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
DECLARE
    v_seat_status seat_status;
    v_order_created INT :=0;
    train_number INT;
    carriage_number INT;
    seat_number INT;
    start_time time;
    end_time time;
-- 启动事务
BEGIN
    SELECT TrainNumber INTO train_number FROM TrainInfo WHERE TrainID = p_train_ID AND OperationStatus='运行中';
    IF EXISTS(SELECT * FROM useable_seats WHERE trainnumber=train_number) THEN
      SELECT seatnumber,carriagenumber INTO seat_number,carriage_number from useable_seats WHERE trainnumber=train_number LIMIT 1;
      SELECT starttime into start_time from schedule WHERE trainid=p_train_id and stationnumber=p_start_station_number;
      SELECT arrivaltime into end_time from schedule WHERE trainid=p_train_id and stationnumber=p_end_station_number;
      INSERT INTO Orders (ID, TrainNumber, StartStationNumber, EndStationNumber, CarriageNumber, SeatNumber, StartTime, EndTime, OrdersStatus,price)
      VALUES (p_id,train_number,p_start_station_number,p_end_station_number,carriage_number,seat_number,start_time,end_time,'待出行',ROUND(0.5 * EXTRACT(EPOCH FROM (end_time - start_time)) / 3600.0 * 100)) 
      RETURNING OrdersNumber INTO v_order_created;
      
      INSERT INTO payorders (usersaccount,ordersnumber)
      VALUES (user_account,v_order_created);
      
      UPDATE seats
      SET seatstatus='已占用'
      WHERE seatnumber=seat_number and carriagenumber=carriage_number and trainnumber=train_number;
      return v_order_created;
    ELSE 
      return -1;
    END IF;
EXCEPTION WHEN OTHERS THEN
     return -1;
  END;
$$;


ALTER FUNCTION public.book_seat_and_create_order(user_account character varying, p_id character varying, p_train_id character varying, p_start_station_number integer, p_end_station_number integer) OWNER TO omm;

--
-- Name: book_seat_and_create_order(character varying, character varying, character varying, integer, integer, integer, integer, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION book_seat_and_create_order(user_account character varying, p_id character varying, p_train_id character varying, p_carriage_number integer, p_seat_number integer, p_start_station_number integer, p_end_station_number integer, p_start_time time without time zone, p_end_time time without time zone) RETURNS integer
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
DECLARE
    v_seat_status seat_status;
    v_order_created INT :=0;
    train_number INT;
-- 启动事务
BEGIN
    SELECT TrainNumber INTO train_number FROM TrainInfo WHERE TrainID = p_train_ID AND OperationStatus='运行中';
    -- 检查座位是否空闲
    SELECT SeatStatus INTO v_seat_status FROM Seats
    WHERE TrainNumber = train_number AND CarriageNumber = p_carriage_number AND SeatNumber = p_seat_number
    FOR UPDATE; -- 锁定选定的座位

    -- 如果找到座位且状态为空闲，则进行预定
    IF v_seat_status = '空闲' THEN
        UPDATE Seats
        SET SeatStatus = '已预订'
        WHERE TrainNumber = train_number AND CarriageNumber = p_carriage_number AND SeatNumber = p_seat_number;
        
        -- 创建订单
        INSERT INTO Orders (ID, TrainNumber, StartStationNumber, EndStationNumber, CarriageNumber, SeatNumber, StartTime, EndTime, OrdersStatus)
        VALUES (p_id, train_number, p_start_station_number, p_end_station_number, p_carriage_number, p_seat_number, p_start_time, p_end_time, '待支付')
        RETURNING OrdersNumber INTO v_order_created;

        -- 如果订单创建成功,则插入订单——账号对应表
       IF v_order_created  > 0 THEN
	    INSERT INTO PayOrders(UsersAccount,OrdersNumber)
		VALUES(user_account,v_order_created);
            COMMIT;
            RETURN v_order_created;
        ELSE
            -- 订单创建失败，回滚事务
            ROLLBACK;
            RETURN 0;
        END IF;
    ELSE
        -- 座位已被预订或不存在，回滚事务
        ROLLBACK;
        RETURN 0;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        -- 发生异常时回滚事务
        ROLLBACK;
        RETURN 0;
END;
$$;


ALTER FUNCTION public.book_seat_and_create_order(user_account character varying, p_id character varying, p_train_id character varying, p_carriage_number integer, p_seat_number integer, p_start_station_number integer, p_end_station_number integer, p_start_time time without time zone, p_end_time time without time zone) OWNER TO jxz;

--
-- Name: cancel_unpaid_orders(integer); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION cancel_unpaid_orders(orders_number integer) RETURNS void
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    	UPDATE Orders SET
    	OrdersStatus = '已取消'
    	WHERE OrdersNumber = orders_number AND OrdersStatus = '待出行'; --增加冗余判断条件避免错误调用
END;
$$;


ALTER FUNCTION public.cancel_unpaid_orders(orders_number integer) OWNER TO jxz;

--
-- Name: get_available_seats(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION get_available_seats(p_train_id character varying) RETURNS integer
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
DECLARE
    available_seats INT;
    train_number INT;
BEGIN
    SELECT TrainNumber INTO train_number FROM TrainInfo WHERE TrainID = p_train_ID AND OperationStatus='运行中';
    SELECT COUNT(*) INTO available_seats
    FROM Seats
    WHERE TrainNumber = train_number AND SeatStatus = '空闲'; -- 确保TrainNumber是整数类型
    RETURN available_seats;
END;
$$;


ALTER FUNCTION public.get_available_seats(p_train_id character varying) OWNER TO jxz;

--
-- Name: get_available_seats_for_train(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION get_available_seats_for_train(p_train_id character varying) RETURNS TABLE(carriagenumber integer, seatnumber integer, seattype seat_type)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
DECLARE
	train_number INT;
BEGIN
    SELECT TrainNumber INTO train_number FROM TrainInfo WHERE TrainID = p_train_ID AND OperationStatus='运行中';
    RETURN QUERY
    SELECT
        s.CarriageNumber,
        s.SeatNumber,
        c.SeatType
    FROM
        Seats s
    JOIN
        Carriage c ON s.TrainNumber = c.TrainNumber AND s.CarriageNumber = c.CarriageNumber
    WHERE
        s.TrainNumber = train_number AND
        s.SeatStatus = '空闲';
END;
$$;


ALTER FUNCTION public.get_available_seats_for_train(p_train_id character varying) OWNER TO jxz;

--
-- Name: get_passenger_names_and_ids(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION get_passenger_names_and_ids(users_account character varying) RETURNS TABLE(personname character varying, id character varying)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    RETURN QUERY
    SELECT
        p.PersonName,
        p.Id
    FROM
        Person p
    JOIN
        Passenger ps ON p.Id = ps.Id
    WHERE
        ps.UsersAccount = users_account;
END;
$$;


ALTER FUNCTION public.get_passenger_names_and_ids(users_account character varying) OWNER TO jxz;

--
-- Name: get_train_info(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION get_train_info(p_train_id character varying) RETURNS TABLE(trainid character varying, traintype character varying, carriagecount integer, departurestation character varying, destinationstation character varying, departuretime time without time zone, arrivaltime time without time zone, duration interval, arrivaldate timestamp without time zone, operationstatus character varying)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    RETURN QUERY
    SELECT 
        TrainID,
        TrainType,
        CarriageCount,
        DepartureStation,
        DestinationStation,
        DepartureTime,
        ArrivalTime,
        Duration,
        ArrivalDate,
        OperationStatus
    FROM 
        TrainInfo
    WHERE 
        TrainID = p_train_id;
END;
$$;


ALTER FUNCTION public.get_train_info(p_train_id character varying) OWNER TO jxz;

--
-- Name: get_train_schedule(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION get_train_schedule(p_train_id character varying) RETURNS TABLE(trainid character varying, stationname character varying, arrivaltime time without time zone, starttime time without time zone, duration interval)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    RETURN QUERY
    SELECT 
        sc.TrainID,
        st.StationName,
        sc.ArrivalTime,
        sc.StartTime,
        (sc.StartTime - sc.ArrivalTime) AS Duration
    FROM 
        Schedule sc
    JOIN 
        Station st ON sc.StationNumber = st.StationNumber
    WHERE 
        sc.TrainID = p_train_id
    ORDER BY 
        sc.ArrivalTime;
END;
$$;


ALTER FUNCTION public.get_train_schedule(p_train_id character varying) OWNER TO jxz;

--
-- Name: get_trains_between_stations(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION get_trains_between_stations(p_departure_station character varying, p_destination_station character varying, p_order_by character varying DEFAULT 'DepartureTime'::character varying) RETURNS TABLE(trainid character varying, traintype character varying, carriagecount integer, departurestation character varying, destinationstation character varying, departuretime time without time zone, arrivaltime time without time zone, duration interval, arrivaldate timestamp without time zone, operationstatus character varying)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    RETURN QUERY
    EXECUTE format(
        'SELECT 
            TrainID,
            CarriageCount,
            DepartureStation,
            DestinationStation,
            DepartureTime,
            ArrivalTime,
            Duration,
            ArrivalDate,
            OperationStatus
        FROM 
            schedule
        WHERE 
            DepartureStation = %L AND
            DestinationStation = %L AND
            OperationStatus = %L
        ORDER BY %I',
        p_departure_station,
        p_destination_station,
        '运行中',
        p_order_by
    );
END;
$$;


ALTER FUNCTION public.get_trains_between_stations(p_departure_station character varying, p_destination_station character varying, p_order_by character varying) OWNER TO jxz;

--
-- Name: get_transfer_trains(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION get_transfer_trains(p_departure_station character varying, p_destination_station character varying, p_order_by character varying DEFAULT 'DepartureTime'::character varying) RETURNS TABLE(firsttrainid character varying, firsttraintype character varying, firstdeparturetime time without time zone, firstarrivaltime time without time zone, transferstation character varying, secondtrainid character varying, secondtraintype character varying, seconddeparturetime time without time zone, secondarrivaltime time without time zone, totalduration interval)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    RETURN QUERY
    WITH first_leg AS (
        SELECT 
            t1.TrainID AS FirstTrainID,
            t1.TrainType AS FirstTrainType,
            t1.DepartureTime AS FirstDepartureTime,
            s1.StationName AS TransferStation,
            s1.ArrivalTime AS FirstArrivalTime,
            t1.Duration AS FirstDuration
        FROM 
            TrainInfo t1
        JOIN 
            Schedule s1 ON t1.TrainID = s1.TrainID
        WHERE 
            t1.DepartureStation = p_departure_station
            AND t1.OperationStatus = '运行中'
    ),
    second_leg AS (
        SELECT 
            t2.TrainID AS SecondTrainID,
            t2.TrainType AS SecondTrainType,
            t2.DepartureTime AS SecondDepartureTime,
            s2.StationName AS TransferStation,
            s2.ArrivalTime AS SecondArrivalTime,
            t2.Duration AS SecondDuration
        FROM 
            TrainInfo t2
        JOIN 
            Schedule s2 ON t2.TrainID = s2.TrainID
        WHERE 
            t2.DestinationStation = p_destination_station
            AND t2.OperationStatus = '运行中'
    )
    SELECT 
        f.FirstTrainID,
        f.FirstTrainType,
        f.FirstDepartureTime,
        f.FirstArrivalTime,
        f.TransferStation,
        s.SecondTrainID,
        s.SecondTrainType,
        s.SecondDepartureTime,
        s.SecondArrivalTime,
        (f.FirstDuration + s.SecondDuration) AS TotalDuration
    FROM 
        first_leg f
    JOIN 
        second_leg s ON f.TransferStation = s.TransferStation
    WHERE 
        f.FirstArrivalTime < s.SecondDepartureTime
    ORDER BY 
         CASE
            WHEN p_order_by = 'DepartureTime' THEN f.DepartureTime
            WHEN p_order_by = 'ArrivalTime' THEN s.ArrivalTime
            WHEN p_order_by = 'Duration' THEN (f.Duration + s.Duration)
        END;
END;
$$;


ALTER FUNCTION public.get_transfer_trains(p_departure_station character varying, p_destination_station character varying, p_order_by character varying) OWNER TO jxz;

--
-- Name: get_valid_train(character varying, character varying); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION get_valid_train(starts_station character varying, ends_station character varying) RETURNS TABLE(trainid character varying, traintype character varying, carriagecount integer, departurestation character varying, destinationstation character varying, departuretime time without time zone, arrivaltime time without time zone, duration time without time zone, arrivaldate timestamp without time zone, operationstatus operation_status)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
DECLARE
	StartNum INT;
	EndNum INT;
BEGIN
		SELECT StationNumber INTO StartNum FROM Station WHERE Station.StationName = starts_station;
		SELECT StationNumber INTO EndNum FROM Station WHERE Station.StationName = ends_station;
    RETURN QUERY
    SELECT TrainID,TrainType,CarriageCount,(select stationname from station where station.stationNumber = trainInfo.DepartureStation),(select stationname from station where station.stationNumber = trainInfo.DestinationStation),departuretime,arrivaltime,duration,arrivaldate,operationstatus FROM TrainInfo WHERE TrainID IN(
    SELECT s1.TrainID
    FROM Schedule s1
    INNER JOIN Schedule s2 ON s1.TrainID = s2.TrainID
    WHERE s1.StationNumber = startNum AND s2.StationNumber = EndNum) AND operationstatus='运行中';--AND s1.ArrivalTime>s2.ArrivalTime);
END;
$$;


ALTER FUNCTION public.get_valid_train(starts_station character varying, ends_station character varying) OWNER TO omm;

--
-- Name: insert_seats_for_carriage(); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION insert_seats_for_carriage() RETURNS trigger
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
DECLARE
    seat_count INT;
    seattype seat_type;
BEGIN
    -- 获取座位类型
    seattype := NEW.SeatType;

    -- 根据座位类型设置座位数量
    IF seattype = '硬座' THEN
        seat_count := 50;
    ELSIF seattype = '软卧' THEN
        seat_count := 20;
    ELSIF seattype = '硬卧' THEN
        seat_count := 30;
    ELSE
        RAISE EXCEPTION 'Unknown seat type: %', seat_type;
    END IF;

    -- 插入相应数量的座位记录到 Seats 表
    FOR i IN 1..seat_count LOOP
        INSERT INTO Seats (TrainNumber, CarriageNumber, SeatNumber, SeatStatus)
        VALUES (NEW.TrainNumber, NEW.CarriageNumber, i, '空闲');
    END LOOP;

    RETURN NEW;
END;
$$;


ALTER FUNCTION public.insert_seats_for_carriage() OWNER TO omm;

--
-- Name: pay_order(character varying); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION pay_order(p_id character varying) RETURNS void
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
  
DECLARE  
    found_order orders%ROWTYPE;  
BEGIN  
    -- 查询订单  
    SELECT * INTO found_order FROM "public"."orders" WHERE "id" = p_id;  
  
    -- 检查订单是否存在  
    IF found_order IS NOT NULL THEN  
        -- 更新订单状态为“已支付”  
        -- 假设"orders_status"是一个枚举类型或外键引用到一个状态表，这里我们直接更新为字符串值  
        UPDATE "public"."orders" SET "ordersstatus" = '待出行' WHERE "id" = p_id;  
        RAISE NOTICE '订单ID % 的状态已更新为“已支付”', p_id;  
    ELSE  
        -- 如果未找到订单，则打印消息  
        RAISE NOTICE '未找到订单ID %', p_id;  
    END IF;  
END;  

$$;


ALTER FUNCTION public.pay_order(p_id character varying) OWNER TO omm;

--
-- Name: query_sale(); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION query_sale() RETURNS TABLE(trainid character varying, seatcount integer, totalseats integer, sold integer)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
  -- Routine body goes here...
   return query select trainID,seatcount,totalseats,(totalseats-seatcount) as sold from trainInfo,(select trainNumber,count(*) as totalseats from seats GROUP BY trainNumber) as t2 WHERE traininfo.trainnumber = t2.trainnumber;
END
$$;


ALTER FUNCTION public.query_sale() OWNER TO omm;

--
-- Name: query_sum_price(); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION query_sum_price() RETURNS TABLE(user_account character varying, price bigint)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
  -- Routine body goes here...
  return query select payorders.usersaccount,sum(price) from payorders,orders WHERE payorders.ordersnumber=orders.ordersnumber GROUP BY usersaccount;
END
$$;


ALTER FUNCTION public.query_sum_price() OWNER TO omm;

--
-- Name: query_sum_price(timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION query_sum_price(start_time timestamp without time zone, end_time timestamp without time zone) RETURNS TABLE(user_account character varying, price bigint)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
  -- Routine body goes here...
  return query select payorders.usersaccount,sum(price) from payorders,orders WHERE payorders.ordersnumber=orders.ordersnumber AND start_time<orderscreatingtime AND orderscreatingtime<end_time GROUP BY usersaccount;
END
$$;


ALTER FUNCTION public.query_sum_price(start_time timestamp without time zone, end_time timestamp without time zone) OWNER TO omm;

--
-- Name: query_train_in_ticket(character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION query_train_in_ticket(bg character varying, ed character varying, tm character varying) RETURNS TABLE(trainnumber integer, traintype character varying, carriagecount integer, departurestation character varying, destinationstation character varying, departuretime time without time zone, arrivaltime time without time zone, duration time without time zone, arrivaldate timestamp without time zone, operationstatus character varying, trainid character varying)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
  -- Routine body goes here...
  RETURN QUERY
    SELECT 
      trainnumber,
      traintype,
      carriagecount,
      (select stationname from station where station.stationNumber = trainInfo.DepartureStation),
			(select stationname from station where station.stationNumber = trainInfo.DestinationStation),
      departuretime,
      arrivaltime,
      duration,
      arrivaldate,
      operationstatus::VARCHAR,
      trainid
     from traininfo where
		TrainID IN(
    SELECT s1.TrainID
    FROM Schedule s1
    INNER JOIN Schedule s2 ON s1.TrainID = s2.TrainID
    WHERE s1.StationNumber IN (SELECT StationNumber FROM Station WHERE Station.StationName LIKE '%'||"bg"||'%')
		AND s2.StationNumber IN (SELECT StationNumber FROM Station WHERE Station.StationName LIKE '%'||"ed"||'%'))
		AND operationstatus='运行中'AND traininfo.arrivaldate::varchar like '%'||"tm"||'%';
END;
$$;


ALTER FUNCTION public.query_train_in_ticket(bg character varying, ed character varying, tm character varying) OWNER TO omm;

--
-- Name: refund_orders(integer); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION refund_orders(p_orders_number integer) RETURNS void
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    UPDATE Orders SET
    OrdersStatus = '已取消'
    WHERE OrdersNumber = p_orders_number AND OrdersStatus = '待出行';--增加冗余判断条件避免错误调用
END;
$$;


ALTER FUNCTION public.refund_orders(p_orders_number integer) OWNER TO jxz;

--
-- Name: release_seats(); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION release_seats() RETURNS trigger
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    IF OLD.ordersstatus = '待出行' AND NEW.ordersstatus= '已取消' THEN 
        UPDATE seats 
        SET seatstatus = '空闲'  
        WHERE trainnumber = OLD.trainnumber and carriagenumber = old.carriagenumber and seatnumber = OLD.seatnumber;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.release_seats() OWNER TO omm;

--
-- Name: show_all_orders(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION show_all_orders(user_account character varying) RETURNS TABLE(ordersnumber integer, trainid character varying, startstation character varying, endstation character varying, carriagenumber integer, seatnumber integer, starttime time without time zone, endtime time without time zone, orderscreatingtime timestamp without time zone, ordersstatus orders_status)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
	BEGIN
		RETURN QUERY
    		SELECT orders.ordersnumber,TrainID,
        (select stationname from station where stationnumber=traininfo.departurestation),
        (select stationname from station where stationnumber=traininfo.destinationstation),CarriageNumber,SeatNumber,StartTime,EndTime,OrdersCreatingTime, OrdersStatus FROM Orders,PayOrders,TrainInfo WHERE UsersAccount = user_account AND Orders.OrdersNumber = PayOrders.OrdersNumber AND TrainInfo.TrainNumber = Orders.TrainNumber;
	END;
	$$;


ALTER FUNCTION public.show_all_orders(user_account character varying) OWNER TO jxz;

--
-- Name: show_all_unpaid_orders(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION show_all_unpaid_orders(user_account character varying) RETURNS TABLE(trainid character varying, startstationnumber integer, endstationnumber integer, carriagenumber integer, seatnumber integer, starttime time without time zone, endtime time without time zone, orderscreatingtime timestamp without time zone, ordersstatus orders_status)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
	BEGIN
		RETURN QUERY
    		SELECT TrainID,StartStationNumber,EndStationNumber,CarriageNumber,SeatNumber,StartTime,EndTime,OrdersCreatingTime, OrdersStatus FROM Orders,PayOrders,TrainInfo WHERE UsersAccount = user_account AND Orders.OrdersNumber = PayOrders.OrdersNumber AND TrainInfo.TrainNumber = Orders.TrainNumber AND OrdersStatus = '待支付';
	END;
	$$;


ALTER FUNCTION public.show_all_unpaid_orders(user_account character varying) OWNER TO jxz;

--
-- Name: show_all_untraveled_orders(character varying); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION show_all_untraveled_orders(user_account character varying) RETURNS TABLE(trainid character varying, startstationnumber integer, endstationnumber integer, carriagenumber integer, seatnumber integer, starttime time without time zone, endtime time without time zone, orderscreatingtime timestamp without time zone, ordersstatus orders_status)
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
	BEGIN
		RETURN QUERY
    		SELECT TrainID,StartStationNumber,EndStationNumber,CarriageNumber,SeatNumber,StartTime,EndTime,OrdersCreatingTime, OrdersStatus FROM Orders,PayOrders,TrainInfo WHERE UsersAccount = user_account AND Orders.OrdersNumber = PayOrders.OrdersNumber AND TrainInfo.TrainNumber = Orders.TrainNumber AND OrdersStatus = '待出行';
	END;
	$$;


ALTER FUNCTION public.show_all_untraveled_orders(user_account character varying) OWNER TO jxz;

--
-- Name: transfer_orders(character varying, integer, integer, integer, time without time zone, time without time zone); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) RETURNS void
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
DECLARE
train_number INT;
BEGIN
    SELECT TrainNumber INTO train_number FROM TrainInfo WHERE TrainID = p_train_ID AND TrainStatus='运行中';
    UPDATE Orders SET
    TrainNumber = train_number,
    CarriagNumber = p_carriage_number,
    SeatNumber = p_seat_number,
    StartTime = p_start_time,
    EndTime = p_end_time
    WHERE OrdersNumber = p_orders_number;
END;
$$;


ALTER FUNCTION public.transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) OWNER TO jxz;

--
-- Name: update_order_to_paid(character varying); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION update_order_to_paid(p_id character varying) RETURNS void
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
  
DECLARE  
    found_order orders%ROWTYPE;  
BEGIN  
    -- 查询订单  
    SELECT * INTO found_order FROM "public"."orders" WHERE "id" = p_id;  
  
    -- 检查订单是否存在  
    IF found_order IS NOT NULL THEN  
        -- 更新订单状态为“已支付”  
        -- 假设"orders_status"是一个枚举类型或外键引用到一个状态表，这里我们直接更新为字符串值  
        UPDATE "public"."orders" SET "ordersstatus" = '已支付' WHERE "id" = p_id;  
        RAISE NOTICE '订单ID % 的状态已更新为“已支付”', p_id;  
    ELSE  
        -- 如果未找到订单，则打印消息  
        RAISE NOTICE '未找到订单ID %', p_id;  
    END IF;  
EXCEPTION  
    WHEN OTHERS THEN  
        -- 如果有任何异常，回滚事务并打印错误消息  
        RAISE EXCEPTION '更新订单ID % 时发生错误', p_id;  
END;  

$$;


ALTER FUNCTION public.update_order_to_paid(p_id character varying) OWNER TO omm;

--
-- Name: update_orders(); Type: FUNCTION; Schema: public; Owner: jxz
--

CREATE FUNCTION update_orders() RETURNS trigger
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    IF OLD.OrdersStatus = '待出行' AND NEW.OrdersStatus = '已取消' THEN 
        UPDATE Orders 
        SET OrdersStatus = '待出行' ,
	CarriageNumber = OLD.CarriageNumber,
	SeatNumber = OLD.SeatNumber
        WHERE OrdersNumber = (SELECT OrdersNumber FROM get_candidate WHERE OLD.TrainNumber = Orders.TrainNumber LIMIT 1);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_orders() OWNER TO jxz;

--
-- Name: update_seats(); Type: FUNCTION; Schema: public; Owner: omm
--

CREATE FUNCTION update_seats() RETURNS trigger
    LANGUAGE plpgsql NOT SHIPPABLE
 AS $$
BEGIN
    IF OLD.seatstatus = '空闲' AND NEW.seatstatus= '已占用' THEN 
        UPDATE traininfo 
        SET seatcount = seatcount - 1 
        WHERE trainnumber = OLD.trainnumber;
				ELSIF OLD.seatstatus = '已占用' AND NEW.seatstatus= '空闲' THEN 
				 UPDATE traininfo 
        SET seatcount = seatcount + 1 
        WHERE trainnumber = OLD.trainnumber;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_seats() OWNER TO omm;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: omm; Tablespace: 
--

CREATE TABLE audit_log (
    audit_id integer NOT NULL,
    operation character varying(10),
    table_name character varying(50),
    record_id character varying(50),
    old_data jsonb,
    new_data jsonb,
    changed_at timestamp without time zone DEFAULT pg_systimestamp()
)
WITH (orientation=row, compression=no);


ALTER TABLE public.audit_log OWNER TO omm;

--
-- Name: carriage; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE carriage (
    trainnumber integer NOT NULL,
    carriagenumber integer NOT NULL,
    seattype seat_type NOT NULL
)
WITH (orientation=row, compression=no);


ALTER TABLE public.carriage OWNER TO jxz;

--
-- Name: TABLE carriage; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE carriage IS '车厢信息表';


--
-- Name: COLUMN carriage.trainnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN carriage.trainnumber IS '列车编号';


--
-- Name: COLUMN carriage.carriagenumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN carriage.carriagenumber IS '车厢编号';


--
-- Name: COLUMN carriage.seattype; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN carriage.seattype IS '座位类型';


--
-- Name: orders; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE orders (
    ordersnumber integer NOT NULL,
    id character varying(20) NOT NULL,
    trainnumber integer NOT NULL,
    startstationnumber integer NOT NULL,
    endstationnumber integer NOT NULL,
    carriagenumber integer,
    seatnumber integer,
    starttime time without time zone NOT NULL,
    endtime time without time zone NOT NULL,
    orderscreatingtime timestamp without time zone DEFAULT pg_systimestamp() NOT NULL,
    ordersstatus orders_status NOT NULL,
    price integer DEFAULT 100 NOT NULL
)
WITH (orientation=row, compression=no);


ALTER TABLE public.orders OWNER TO jxz;

--
-- Name: TABLE orders; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE orders IS '订单信息表';


--
-- Name: COLUMN orders.ordersnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.ordersnumber IS '订单编号';


--
-- Name: COLUMN orders.id; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.id IS '乘客ID，与乘客表的主键关联';


--
-- Name: COLUMN orders.trainnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.trainnumber IS '列车编号，与列车信息表的主键关联';


--
-- Name: COLUMN orders.startstationnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.startstationnumber IS '起始站编号，与车站表的主键关联';


--
-- Name: COLUMN orders.endstationnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.endstationnumber IS '终点站编号，与车站表的主键关联';


--
-- Name: COLUMN orders.carriagenumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.carriagenumber IS '车厢编号';


--
-- Name: COLUMN orders.seatnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.seatnumber IS '座位编号';


--
-- Name: COLUMN orders.starttime; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.starttime IS '订单中列车的起始时间';


--
-- Name: COLUMN orders.endtime; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.endtime IS '订单中列车的结束时间';


--
-- Name: COLUMN orders.orderscreatingtime; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.orderscreatingtime IS '订单创建时间，默认为当前时间';


--
-- Name: COLUMN orders.ordersstatus; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.ordersstatus IS '订单状态，例如：待支付、已支付、已取消等';


--
-- Name: COLUMN orders.price; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN orders.price IS '订单价格';


--
-- Name: passenger; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE passenger (
    usersaccount character varying(50) NOT NULL,
    id character varying(20) NOT NULL,
    telephonenumber character varying(50),
    passengertype passenger_type
)
WITH (orientation=row, compression=no);


ALTER TABLE public.passenger OWNER TO jxz;

--
-- Name: TABLE passenger; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE passenger IS '乘客信息表';


--
-- Name: COLUMN passenger.usersaccount; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN passenger.usersaccount IS '用户账号';


--
-- Name: COLUMN passenger.id; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN passenger.id IS '乘客身份证号';


--
-- Name: COLUMN passenger.telephonenumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN passenger.telephonenumber IS '联系电话';


--
-- Name: COLUMN passenger.passengertype; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN passenger.passengertype IS '乘客类型';


--
-- Name: payorders; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE payorders (
    usersaccount character varying(20) NOT NULL,
    ordersnumber integer NOT NULL
)
WITH (orientation=row, compression=no);


ALTER TABLE public.payorders OWNER TO jxz;

--
-- Name: TABLE payorders; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE payorders IS '待支付订单账户表';


--
-- Name: COLUMN payorders.usersaccount; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN payorders.usersaccount IS '用户账号';


--
-- Name: COLUMN payorders.ordersnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN payorders.ordersnumber IS '订单编号';


--
-- Name: person; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE person (
    id character varying(20) NOT NULL,
    personname character varying(50),
    sex sex,
    address character varying(255)
)
WITH (orientation=row, compression=no);


ALTER TABLE public.person OWNER TO jxz;

--
-- Name: TABLE person; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE person IS '人员信息表';


--
-- Name: COLUMN person.id; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN person.id IS '身份证号';


--
-- Name: COLUMN person.personname; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN person.personname IS '姓名';


--
-- Name: COLUMN person.sex; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN person.sex IS '性别';


--
-- Name: COLUMN person.address; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN person.address IS '地址';


--
-- Name: schedule; Type: TABLE; Schema: public; Owner: omm; Tablespace: 
--

CREATE TABLE schedule (
    trainid character varying(20) NOT NULL,
    stationnumber integer NOT NULL,
    arrivaltime time without time zone,
    starttime time without time zone
)
WITH (orientation=row, compression=no);


ALTER TABLE public.schedule OWNER TO omm;

--
-- Name: TABLE schedule; Type: COMMENT; Schema: public; Owner: omm
--

COMMENT ON TABLE schedule IS '列车时刻表';


--
-- Name: COLUMN schedule.trainid; Type: COMMENT; Schema: public; Owner: omm
--

COMMENT ON COLUMN schedule.trainid IS '车次';


--
-- Name: COLUMN schedule.stationnumber; Type: COMMENT; Schema: public; Owner: omm
--

COMMENT ON COLUMN schedule.stationnumber IS '车站编号';


--
-- Name: COLUMN schedule.arrivaltime; Type: COMMENT; Schema: public; Owner: omm
--

COMMENT ON COLUMN schedule.arrivaltime IS '列车到达时间';


--
-- Name: COLUMN schedule.starttime; Type: COMMENT; Schema: public; Owner: omm
--

COMMENT ON COLUMN schedule.starttime IS '列车发车时间';


--
-- Name: seats; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE seats (
    trainnumber integer NOT NULL,
    carriagenumber integer NOT NULL,
    seatnumber integer NOT NULL,
    seatstatus seat_status NOT NULL
)
WITH (orientation=row, compression=no);


ALTER TABLE public.seats OWNER TO jxz;

--
-- Name: TABLE seats; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE seats IS '座位信息表';


--
-- Name: COLUMN seats.trainnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN seats.trainnumber IS '列车编号';


--
-- Name: COLUMN seats.carriagenumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN seats.carriagenumber IS '车厢编号';


--
-- Name: COLUMN seats.seatnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN seats.seatnumber IS '座位编号';


--
-- Name: COLUMN seats.seatstatus; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN seats.seatstatus IS '座位状态';


--
-- Name: station; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE station (
    stationnumber integer NOT NULL,
    stationname character varying(100)
)
WITH (orientation=row, compression=no);


ALTER TABLE public.station OWNER TO jxz;

--
-- Name: TABLE station; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE station IS '车站表';


--
-- Name: COLUMN station.stationnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN station.stationnumber IS '车站编号';


--
-- Name: COLUMN station.stationname; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN station.stationname IS '车站名称';


--
-- Name: traininfo; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE traininfo (
    trainnumber integer NOT NULL,
    traintype character varying(50),
    carriagecount integer,
    departurestation integer,
    destinationstation integer,
    departuretime time without time zone,
    arrivaltime time without time zone,
    duration time without time zone,
    arrivaldate timestamp(0) without time zone,
    operationstatus operation_status,
    trainid character varying(20) NOT NULL,
    seatcount integer
)
WITH (orientation=row, compression=no);


ALTER TABLE public.traininfo OWNER TO jxz;

--
-- Name: TABLE traininfo; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE traininfo IS '列车信息表';


--
-- Name: COLUMN traininfo.trainnumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.trainnumber IS '列车编号';


--
-- Name: COLUMN traininfo.traintype; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.traintype IS '列车类型';


--
-- Name: COLUMN traininfo.carriagecount; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.carriagecount IS '车厢数量';


--
-- Name: COLUMN traininfo.departurestation; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.departurestation IS '出发站';


--
-- Name: COLUMN traininfo.destinationstation; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.destinationstation IS '目的站';


--
-- Name: COLUMN traininfo.departuretime; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.departuretime IS '出发时间';


--
-- Name: COLUMN traininfo.arrivaltime; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.arrivaltime IS '到达时间';


--
-- Name: COLUMN traininfo.duration; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.duration IS '旅程时间';


--
-- Name: COLUMN traininfo.arrivaldate; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.arrivaldate IS '到达日期';


--
-- Name: COLUMN traininfo.operationstatus; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.operationstatus IS '运营状态';


--
-- Name: COLUMN traininfo.trainid; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.trainid IS '车次';


--
-- Name: COLUMN traininfo.seatcount; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN traininfo.seatcount IS '座位数';


--
-- Name: useable_seats; Type: VIEW; Schema: public; Owner: omm
--

CREATE  DEFINER = omm  VIEW useable_seats(trainnumber,carriagenumber,seatnumber,seatstatus) AS
    SELECT  * FROM seats WHERE (seats.seatstatus = '空闲'::seat_status);


ALTER VIEW public.useable_seats OWNER TO omm;

--
-- Name: users; Type: TABLE; Schema: public; Owner: jxz; Tablespace: 
--

CREATE TABLE users (
    usersaccount character varying(50) NOT NULL,
    id character varying(20),
    telephonenumber character varying(50),
    password character varying(50),
    email character varying(50),
    userstype character varying(50)
)
WITH (orientation=row, compression=no);


ALTER TABLE public.users OWNER TO jxz;

--
-- Name: TABLE users; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON TABLE users IS '用户信息表';


--
-- Name: COLUMN users.usersaccount; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN users.usersaccount IS '用户账号';


--
-- Name: COLUMN users.id; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN users.id IS '用户身份证号码';


--
-- Name: COLUMN users.telephonenumber; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN users.telephonenumber IS '联系电话';


--
-- Name: COLUMN users.password; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN users.password IS '密码';


--
-- Name: COLUMN users.email; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN users.email IS '电子邮件';


--
-- Name: COLUMN users.userstype; Type: COMMENT; Schema: public; Owner: jxz
--

COMMENT ON COLUMN users.userstype IS '用户类型';


--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE; Schema: public; Owner: omm
--

CREATE  SEQUENCE audit_log_audit_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.audit_log_audit_id_seq OWNER TO omm;

--
-- Name: audit_log_audit_id_seq; Type: LARGE SEQUENCE OWNED BY; Schema: public; Owner: omm
--

ALTER  SEQUENCE audit_log_audit_id_seq OWNED BY audit_log.audit_id;


--
-- Name: orders_ordersnumber_seq; Type: SEQUENCE; Schema: public; Owner: jxz
--

CREATE  SEQUENCE orders_ordersnumber_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_ordersnumber_seq OWNER TO jxz;

--
-- Name: orders_ordersnumber_seq; Type: LARGE SEQUENCE OWNED BY; Schema: public; Owner: jxz
--

ALTER  SEQUENCE orders_ordersnumber_seq OWNED BY orders.ordersnumber;


--
-- Name: audit_id; Type: DEFAULT; Schema: public; Owner: omm
--

ALTER TABLE audit_log ALTER COLUMN audit_id SET DEFAULT nextval('audit_log_audit_id_seq'::regclass);


--
-- Name: ordersnumber; Type: DEFAULT; Schema: public; Owner: jxz
--

ALTER TABLE orders ALTER COLUMN ordersnumber SET DEFAULT nextval('orders_ordersnumber_seq'::regclass);


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: omm
--

COPY audit_log (audit_id, operation, table_name, record_id, old_data, new_data, changed_at) FROM stdin;
1	INSERT	orders	110101198001010000	\N	{"id": "110101198001010000", "price": 100, "endtime": "12:00:00", "starttime": "08:00:00", "seatnumber": 30, "trainnumber": 1, "ordersnumber": 40, "ordersstatus": "待支付", "carriagenumber": 1, "endstationnumber": 2, "orderscreatingtime": "2024-06-20 08:00:00", "startstationnumber": 1}	2024-06-20 15:49:15.949566
2	INSERT	orders	110101198001010001	\N	{"id": "110101198001010001", "price": 100, "endtime": "14:00:00", "starttime": "09:00:00", "seatnumber": 29, "trainnumber": 2, "ordersnumber": 41, "ordersstatus": "待出行", "carriagenumber": 2, "endstationnumber": 3, "orderscreatingtime": "2024-06-21 09:00:00", "startstationnumber": 2}	2024-06-20 15:49:15.950124
3	INSERT	orders	110101198001010002	\N	{"id": "110101198001010002", "price": 100, "endtime": "16:30:00", "starttime": "15:00:00", "seatnumber": 30, "trainnumber": 3, "ordersnumber": 42, "ordersstatus": "待出行", "carriagenumber": 3, "endstationnumber": 4, "orderscreatingtime": "2024-06-22 15:00:00", "startstationnumber": 3}	2024-06-20 15:49:15.950322
4	INSERT	orders	110101198001010003	\N	{"id": "110101198001010003", "price": 100, "endtime": "23:00:00", "starttime": "17:00:00", "seatnumber": 21, "trainnumber": 4, "ordersnumber": 43, "ordersstatus": "待支付", "carriagenumber": 4, "endstationnumber": 5, "orderscreatingtime": "2024-06-23 17:00:00", "startstationnumber": 4}	2024-06-20 15:49:15.950487
5	INSERT	orders	110101198001010004	\N	{"id": "110101198001010004", "price": 100, "endtime": "14:00:00", "starttime": "06:00:00", "seatnumber": 18, "trainnumber": 5, "ordersnumber": 44, "ordersstatus": "待支付", "carriagenumber": 5, "endstationnumber": 6, "orderscreatingtime": "2024-06-24 06:00:00", "startstationnumber": 5}	2024-06-20 15:49:15.950629
6	INSERT	orders	110101198001010005	\N	{"id": "110101198001010005", "price": 100, "endtime": "20:30:00", "starttime": "15:30:00", "seatnumber": 15, "trainnumber": 6, "ordersnumber": 45, "ordersstatus": "待出行", "carriagenumber": 6, "endstationnumber": 1, "orderscreatingtime": "2024-06-25 15:30:00", "startstationnumber": 6}	2024-06-20 15:49:15.950791
7	INSERT	orders	110101198001010006	\N	{"id": "110101198001010006", "price": 100, "endtime": "12:00:00", "starttime": "08:00:00", "seatnumber": 1, "trainnumber": 1, "ordersnumber": 46, "ordersstatus": "待支付", "carriagenumber": 1, "endstationnumber": 3, "orderscreatingtime": "2024-06-26 08:00:00", "startstationnumber": 1}	2024-06-20 15:49:15.950926
8	INSERT	orders	110101198001010007	\N	{"id": "110101198001010007", "price": 100, "endtime": "14:00:00", "starttime": "09:00:00", "seatnumber": 3, "trainnumber": 2, "ordersnumber": 47, "ordersstatus": "待支付", "carriagenumber": 2, "endstationnumber": 4, "orderscreatingtime": "2024-06-27 09:00:00", "startstationnumber": 2}	2024-06-20 15:49:15.951056
9	INSERT	orders	110101198001010008	\N	{"id": "110101198001010008", "price": 100, "endtime": "16:30:00", "starttime": "15:00:00", "seatnumber": 4, "trainnumber": 3, "ordersnumber": 48, "ordersstatus": "待出行", "carriagenumber": 3, "endstationnumber": 5, "orderscreatingtime": "2024-06-28 15:00:00", "startstationnumber": 3}	2024-06-20 15:49:15.951186
10	INSERT	orders	110101198001010009	\N	{"id": "110101198001010009", "price": 100, "endtime": "23:00:00", "starttime": "17:00:00", "seatnumber": 5, "trainnumber": 4, "ordersnumber": 49, "ordersstatus": "待支付", "carriagenumber": 4, "endstationnumber": 6, "orderscreatingtime": "2024-06-29 17:00:00", "startstationnumber": 4}	2024-06-20 15:49:15.951328
11	INSERT	orders	110101198001010010	\N	{"id": "110101198001010010", "price": 100, "endtime": "14:00:00", "starttime": "06:00:00", "seatnumber": 7, "trainnumber": 5, "ordersnumber": 50, "ordersstatus": "待支付", "carriagenumber": 5, "endstationnumber": 1, "orderscreatingtime": "2024-06-30 06:00:00", "startstationnumber": 5}	2024-06-20 15:49:15.951458
12	INSERT	orders	110101198001010015	\N	{"id": "110101198001010015", "price": 100, "endtime": "23:00:00", "starttime": "17:00:00", "seatnumber": 6, "trainnumber": 4, "ordersnumber": 51, "ordersstatus": "待出行", "carriagenumber": 4, "endstationnumber": 3, "orderscreatingtime": "2024-07-06 17:00:00", "startstationnumber": 4}	2024-06-20 15:49:15.951588
13	INSERT	orders	110101198001010016	\N	{"id": "110101198001010016", "price": 100, "endtime": "16:30:00", "starttime": "15:00:00", "seatnumber": 13, "trainnumber": 3, "ordersnumber": 52, "ordersstatus": "待支付", "carriagenumber": 3, "endstationnumber": 2, "orderscreatingtime": "2024-07-07 15:00:00", "startstationnumber": 3}	2024-06-20 15:49:15.951733
14	INSERT	orders	110101198001010017	\N	{"id": "110101198001010017", "price": 100, "endtime": "14:00:00", "starttime": "09:00:00", "seatnumber": 14, "trainnumber": 2, "ordersnumber": 53, "ordersstatus": "待支付", "carriagenumber": 2, "endstationnumber": 1, "orderscreatingtime": "2024-07-08 09:00:00", "startstationnumber": 2}	2024-06-20 15:49:15.951868
15	INSERT	orders	110101198001010018	\N	{"id": "110101198001010018", "price": 100, "endtime": "12:00:00", "starttime": "08:00:00", "seatnumber": 15, "trainnumber": 1, "ordersnumber": 54, "ordersstatus": "待出行", "carriagenumber": 1, "endstationnumber": 6, "orderscreatingtime": "2024-07-09 08:00:00", "startstationnumber": 1}	2024-06-20 15:49:15.951996
16	INSERT	orders	110101198001010019	\N	{"id": "110101198001010019", "price": 100, "endtime": "14:00:00", "starttime": "06:00:00", "seatnumber": 11, "trainnumber": 5, "ordersnumber": 55, "ordersstatus": "待支付", "carriagenumber": 5, "endstationnumber": 4, "orderscreatingtime": "2024-07-10 06:00:00", "startstationnumber": 5}	2024-06-20 15:49:15.952126
17	INSERT	orders	110101198001010020	\N	{"id": "110101198001010020", "price": 100, "endtime": "20:30:00", "starttime": "15:30:00", "seatnumber": 11, "trainnumber": 6, "ordersnumber": 56, "ordersstatus": "待支付", "carriagenumber": 6, "endstationnumber": 5, "orderscreatingtime": "2024-07-11 15:30:00", "startstationnumber": 6}	2024-06-20 15:49:15.952264
\.
;

--
-- Name: audit_log_audit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: omm
--

SELECT pg_catalog.setval('audit_log_audit_id_seq', 17, true);


--
-- Data for Name: carriage; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY carriage (trainnumber, carriagenumber, seattype) FROM stdin;
1	1	硬座
1	2	软卧
1	3	硬卧
2	1	硬座
2	2	软卧
2	3	硬卧
2	4	硬座
2	5	软卧
2	6	硬卧
3	1	硬座
3	2	软卧
3	3	硬卧
4	1	硬座
4	2	软卧
4	3	硬卧
5	1	硬座
5	2	软卧
5	3	硬卧
6	1	硬座
6	2	软卧
6	3	硬卧
6	4	硬座
6	5	软卧
6	6	硬卧
7	1	硬座
8	1	软卧
8	2	硬卧
8	3	硬座
8	4	软卧
8	5	硬卧
8	6	硬座
9	1	硬座
9	2	软卧
9	3	硬座
9	4	硬座
9	5	软卧
9	6	硬座
10	1	硬卧
10	2	软卧
10	3	硬座
11	1	硬座
11	2	软卧
11	3	硬卧
12	1	硬卧
12	2	软卧
12	3	硬座
13	1	硬座
13	2	硬卧
13	3	软卧
\.
;

--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY orders (ordersnumber, id, trainnumber, startstationnumber, endstationnumber, carriagenumber, seatnumber, starttime, endtime, orderscreatingtime, ordersstatus, price) FROM stdin;
40	110101198001010000	1	1	2	1	30	08:00:00	12:00:00	2024-06-20 08:00:00	待支付	100
41	110101198001010001	2	2	3	2	29	09:00:00	14:00:00	2024-06-21 09:00:00	待出行	100
42	110101198001010002	3	3	4	3	30	15:00:00	16:30:00	2024-06-22 15:00:00	待出行	100
43	110101198001010003	4	4	5	4	21	17:00:00	23:00:00	2024-06-23 17:00:00	待支付	100
44	110101198001010004	5	5	6	5	18	06:00:00	14:00:00	2024-06-24 06:00:00	待支付	100
45	110101198001010005	6	6	1	6	15	15:30:00	20:30:00	2024-06-25 15:30:00	待出行	100
46	110101198001010006	1	1	3	1	1	08:00:00	12:00:00	2024-06-26 08:00:00	待支付	100
47	110101198001010007	2	2	4	2	3	09:00:00	14:00:00	2024-06-27 09:00:00	待支付	100
48	110101198001010008	3	3	5	3	4	15:00:00	16:30:00	2024-06-28 15:00:00	待出行	100
49	110101198001010009	4	4	6	4	5	17:00:00	23:00:00	2024-06-29 17:00:00	待支付	100
50	110101198001010010	5	5	1	5	7	06:00:00	14:00:00	2024-06-30 06:00:00	待支付	100
51	110101198001010015	4	4	3	4	6	17:00:00	23:00:00	2024-07-06 17:00:00	待出行	100
52	110101198001010016	3	3	2	3	13	15:00:00	16:30:00	2024-07-07 15:00:00	待支付	100
53	110101198001010017	2	2	1	2	14	09:00:00	14:00:00	2024-07-08 09:00:00	待支付	100
54	110101198001010018	1	1	6	1	15	08:00:00	12:00:00	2024-07-09 08:00:00	待出行	100
55	110101198001010019	5	5	4	5	11	06:00:00	14:00:00	2024-07-10 06:00:00	待支付	100
56	110101198001010020	6	6	5	6	11	15:30:00	20:30:00	2024-07-11 15:30:00	待支付	100
\.
;

--
-- Name: orders_ordersnumber_seq; Type: SEQUENCE SET; Schema: public; Owner: jxz
--

SELECT pg_catalog.setval('orders_ordersnumber_seq', 56, true);


--
-- Data for Name: passenger; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY passenger (usersaccount, id, telephonenumber, passengertype) FROM stdin;
user001	110101198001010000	13800000101	成人
user001	110101198001010001	13800000102	儿童
user002	110101198001010002	13800000103	学生
user002	110101198001010003	13800000104	成人
user003	110101198001010004	13800000105	成人
user003	110101198001010005	13800000106	儿童
user004	110101198001010006	13800000107	学生
user004	110101198001010007	13800000108	残军
user005	110101198001010008	13800000109	成人
user005	110101198001010009	13800000110	儿童
user004	110101198001010015	13800000111	学生
user003	110101198001010011	13800000112	成人
user004	110101198001010010	13800000113	残军
user004	110101198001010016	13800000114	儿童
user002	110101198001010017	13800000115	学生
user002	110101198001010012	13800000116	成人
user001	110101198001010013	13800000117	成人
user001	110101198001010018	13800000118	学生
user003	110101198001010014	13800000119	儿童
user003	110101198001010019	13800000120	学生
user005	110101198001010002	13800000119	儿童
user004	110101198001010000	13800000120	学生
\.
;

--
-- Data for Name: payorders; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY payorders (usersaccount, ordersnumber) FROM stdin;
\.
;

--
-- Data for Name: person; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY person (id, personname, sex, address) FROM stdin;
110101198001010000	张三	男	北京市朝阳区望京SOHO
110101198001010001	李四	女	上海市浦东新区张江高科技园区
110101198001010002	王五	男	广州市天河区珠江新城
110101198001010003	赵六	女	深圳市南山区科技园
110101198001010004	孙七	男	杭州市西湖区西溪
110101198001010005	周八	女	成都市高新区天府软件园
110101198001010006	吴九	男	西安市高新区
110101198001010007	郑十	女	苏州市工业园区
110101198001010008	刘十一	男	重庆市渝北区
110101198001010009	陈十二	女	武汉市洪山区
110101198001010010	钱十三	男	南京市建邺区
110101198001010011	孙十四	女	苏州市姑苏区
110101198001010012	周十五	男	长沙市岳麓区
110101198001010013	吴十六	女	沈阳市和平区
110101198001010014	郑十七	男	成都市武侯区
110101198001010015	王十八	女	杭州市滨江区
110101198001010016	冯十九	男	重庆市南岸区
110101198001010017	陈二十	女	武汉市江汉区
110101198001010018	褚二十一	男	南京市鼓楼区
110101198001010019	卫二十二	女	苏州市吴中区
110101198001010020	蒋二十三	男	长沙市天心区
110101198001010021	沈二十四	女	沈阳市沈河区
110101198001010022	韩二十五	男	成都市青羊区
110101198001010023	朱二十六	女	杭州市上城区
110101198001010024	秦二十七	男	重庆市渝中区
110101198001010025	尤二十八	女	武汉市武昌区
110101198001010026	许二十九	男	南京市栖霞区
110101198001010027	何三十	女	苏州市相城区
110101198001010028	吕三十一	男	长沙市开福区
110101198001010029	施三十二	女	沈阳市大东区
110101198001010030	张三十三	男	成都市金牛区
110101198001010031	孔三十四	女	杭州市下城区
110101198001010032	曹三十五	男	重庆市江北区
110101198001010033	严三十六	女	武汉市汉阳区
110101198001010034	华三十七	男	南京市江宁区
110101198001010035	金三十八	女	苏州市吴江区
110101198001010036	魏三十九	男	长沙市雨花区
110101198001010037	陶四十	女	沈阳市铁西区
110101198001010038	江四十一	男	成都市成华区
110101198001010039	郭四十二	女	杭州市拱墅区
\.
;

--
-- Data for Name: schedule; Type: TABLE DATA; Schema: public; Owner: omm
--

COPY schedule (trainid, stationnumber, arrivaltime, starttime) FROM stdin;
G1001	1	\N	08:00:00
G1001	2	12:00:00	\N
G1002	2	\N	09:00:00
G1002	3	14:00:00	\N
Z1003	3	\N	15:00:00
Z1003	4	16:30:00	\N
K1004	4	\N	17:00:00
D1005	5	\N	06:00:00
D1005	6	14:00:00	\N
Z1006	6	\N	15:30:00
Z1006	1	20:30:00	\N
G1007	1	\N	07:00:00
G1007	3	12:00:00	\N
G1008	2	18:00:00	\N
D1011	5	11:00:00	11:10:00
D1011	1	09:45:00	\N
Z1040	4	16:00:00	\N
G1001	3	08:30:00	08:45:00
G1001	4	12:00:00	12:15:00
G1002	5	13:00:00	13:20:00
Z1003	2	10:10:00	10:25:00
Z1003	6	14:00:00	14:10:00
K1004	3	11:00:00	11:15:00
K1004	5	23:00:00	\N
D1005	4	12:00:00	12:10:00
D1005	1	16:00:00	16:15:00
Z1006	2	13:00:00	13:20:00
Z1006	3	17:00:00	17:15:00
G1007	6	08:00:00	08:10:00
G1007	5	12:00:00	12:15:00
G1008	1	08:45:00	09:00:00
G1008	4	13:00:00	13:20:00
D1011	2	09:30:00	09:40:00
D1011	6	\N	06:30:00
T1012	3	15:00:00	\N
T1012	1	\N	10:00:00
Z1040	5	\N	10:00:00
Z1040	2	16:00:00	16:15:00
G1001	6	14:00:00	14:20:00
G1002	1	16:30:00	16:45:00
K1004	2	19:00:00	19:10:00
D1005	3	20:00:00	20:20:00
Z1006	4	21:00:00	21:10:00
G1008	3	\N	13:00:00
G1002	4	21:00:00	21:20:00
Z1003	5	22:00:00	22:15:00
K1004	1	23:00:00	23:10:00
D1005	2	00:00:00	00:15:00
\.
;

--
-- Data for Name: seats; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY seats (trainnumber, carriagenumber, seatnumber, seatstatus) FROM stdin;
\.
;

--
-- Data for Name: station; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY station (stationnumber, stationname) FROM stdin;
1	北京南站
2	上海虹桥站
3	广州南站
4	深圳北站
5	成都东站
6	杭州东站
\.
;

--
-- Data for Name: traininfo; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY traininfo (trainnumber, traintype, carriagecount, departurestation, destinationstation, departuretime, arrivaltime, duration, arrivaldate, operationstatus, trainid, seatcount) FROM stdin;
1	高速列车	3	1	2	08:00:00	12:00:00	04:00:00	2024-06-20 00:00:00	运行中	G1001	\N
2	城际列车	6	2	3	09:00:00	14:00:00	05:00:00	2024-06-21 00:00:00	运行中	G1002	\N
3	直达特快	3	3	4	15:00:00	16:30:00	01:30:00	2024-06-22 00:00:00	运行中	Z1003	\N
4	快速列车	3	4	5	17:00:00	23:00:00	06:00:00	2024-06-23 00:00:00	运行中	K1004	\N
5	高速动车	3	5	6	06:00:00	14:00:00	08:00:00	2024-06-24 00:00:00	运行中	D1005	\N
14	高速动车	3	5	6	06:00:00	14:00:00	08:00:00	2024-06-24 00:00:00	未运行	D1005	\N
6	直达特快	6	6	1	15:30:00	20:30:00	05:00:00	2024-06-25 00:00:00	运行中	Z1006	\N
7	高速列车	1	1	3	07:00:00	12:00:00	05:00:00	2024-06-26 00:00:00	运行中	G1007	\N
8	城际列车	6	3	2	13:00:00	18:00:00	05:00:00	2024-06-27 00:00:00	运行中	G1008	\N
9	高速列车	6	3	2	13:00:00	18:00:00	05:00:00	2024-06-27 00:00:00	运行中	G1009	\N
10	城际列车	6	3	2	13:00:00	18:00:00	05:00:00	2024-06-27 00:00:00	运行中	C1010	\N
11	高速动车	6	6	1	06:30:00	09:45:00	03:15:00	2024-07-01 00:00:00	运行中	D1011	\N
15	高速动车	3	6	1	06:30:00	09:45:00	03:15:00	2024-07-01 00:00:00	未运行	D1011	\N
12	特快列车	3	1	3	10:00:00	15:00:00	05:00:00	2024-07-02 00:00:00	运行中	T1012	\N
13	直达特快	3	5	4	10:00:00	16:00:00	06:00:00	2024-07-05 00:00:00	运行中	Z1040	\N
\.
;

--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: jxz
--

COPY users (usersaccount, id, telephonenumber, password, email, userstype) FROM stdin;
user001	110101198001010000	13800000101	pass001	zhangsan001@example.com	普通用户
user002	110101198001010001	13800000102	pass002	lisi002@example.com	VIP用户
user003	110101198001010002	13800000103	pass003	wangwu003@example.com	普通用户
user004	110101198001010003	13800000104	pass004	zhaoliu004@example.com	普通用户
user005	110101198001010004	13800000105	pass005	sunqi005@example.com	VIP用户
\.
;

--
-- Name: audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: omm; Tablespace: 
--

ALTER TABLE audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY  (audit_id);


--
-- Name: carriage_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE carriage
    ADD CONSTRAINT carriage_pkey PRIMARY KEY  (trainnumber, carriagenumber);


--
-- Name: orders_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY  (ordersnumber);


--
-- Name: passenger_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE passenger
    ADD CONSTRAINT passenger_pkey PRIMARY KEY  (usersaccount, id);


--
-- Name: payorders_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE payorders
    ADD CONSTRAINT payorders_pkey PRIMARY KEY  (usersaccount, ordersnumber);


--
-- Name: person_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE person
    ADD CONSTRAINT person_pkey PRIMARY KEY  (id);


--
-- Name: schedule_pkey; Type: CONSTRAINT; Schema: public; Owner: omm; Tablespace: 
--

ALTER TABLE schedule
    ADD CONSTRAINT schedule_pkey PRIMARY KEY  (trainid, stationnumber);


--
-- Name: seats_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE seats
    ADD CONSTRAINT seats_pkey PRIMARY KEY  (trainnumber, carriagenumber, seatnumber);


--
-- Name: station_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE station
    ADD CONSTRAINT station_pkey PRIMARY KEY  (stationnumber);


--
-- Name: traininfo_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE traininfo
    ADD CONSTRAINT traininfo_pkey PRIMARY KEY  (trainnumber);


--
-- Name: users_pkey; Type: CONSTRAINT; Schema: public; Owner: jxz; Tablespace: 
--

ALTER TABLE users
    ADD CONSTRAINT users_pkey PRIMARY KEY  (usersaccount);


--
-- Name: select_index; Type: INDEX; Schema: public; Owner: jxz; Tablespace: 
--

CREATE INDEX select_index ON traininfo USING btree (departurestation, destinationstation, arrivaldate) TABLESPACE pg_default;


--
-- Name: trainid_index; Type: INDEX; Schema: public; Owner: jxz; Tablespace: 
--

CREATE INDEX trainid_index ON traininfo USING btree (trainid) TABLESPACE pg_default;


--
-- Name: after_orders_update; Type: TRIGGER; Schema: public; Owner: jxz
--

CREATE TRIGGER after_orders_update AFTER UPDATE OF ordersstatus ON orders FOR EACH ROW EXECUTE PROCEDURE release_seats();


--
-- Name: after_seats_update; Type: TRIGGER; Schema: public; Owner: jxz
--

CREATE TRIGGER after_seats_update AFTER UPDATE ON seats FOR EACH ROW EXECUTE PROCEDURE update_seats();


--
-- Name: table_audit1; Type: TRIGGER; Schema: public; Owner: jxz
--

CREATE TRIGGER table_audit1 AFTER INSERT ON orders FOR EACH ROW EXECUTE PROCEDURE audit_trigger_fn();


--
-- Name: table_audit2; Type: TRIGGER; Schema: public; Owner: jxz
--

CREATE TRIGGER table_audit2 AFTER UPDATE ON orders FOR EACH ROW EXECUTE PROCEDURE audit_trigger_fn();


--
-- Name: update_candidate; Type: TRIGGER; Schema: public; Owner: jxz
--

CREATE TRIGGER update_candidate AFTER UPDATE OF ordersstatus ON orders FOR EACH ROW WHEN ((new.ordersstatus IS DISTINCT FROM old.ordersstatus)) EXECUTE PROCEDURE update_orders();


--
-- Name: orders_endstationnumber_fkey; Type: FK CONSTRAINT; Schema: public; Owner: jxz
--

ALTER TABLE orders
    ADD CONSTRAINT orders_endstationnumber_fkey FOREIGN KEY (endstationnumber) REFERENCES station(stationnumber);


--
-- Name: orders_startstationnumber_fkey; Type: FK CONSTRAINT; Schema: public; Owner: jxz
--

ALTER TABLE orders
    ADD CONSTRAINT orders_startstationnumber_fkey FOREIGN KEY (startstationnumber) REFERENCES station(stationnumber);


--
-- Name: orders_trainnumber_fkey; Type: FK CONSTRAINT; Schema: public; Owner: jxz
--

ALTER TABLE orders
    ADD CONSTRAINT orders_trainnumber_fkey FOREIGN KEY (trainnumber) REFERENCES traininfo(trainnumber);


--
-- Name: passenger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: jxz
--

ALTER TABLE passenger
    ADD CONSTRAINT passenger_id_fkey FOREIGN KEY (id) REFERENCES person(id);


--
-- Name: payorders_ordersnumber_fkey; Type: FK CONSTRAINT; Schema: public; Owner: jxz
--

ALTER TABLE payorders
    ADD CONSTRAINT payorders_ordersnumber_fkey FOREIGN KEY (ordersnumber) REFERENCES orders(ordersnumber);


--
-- Name: schedule_stationnumber_fkey; Type: FK CONSTRAINT; Schema: public; Owner: omm
--

ALTER TABLE schedule
    ADD CONSTRAINT schedule_stationnumber_fkey FOREIGN KEY (stationnumber) REFERENCES station(stationnumber);


--
-- Name: seats_trainnumber_fkey; Type: FK CONSTRAINT; Schema: public; Owner: jxz
--

ALTER TABLE seats
    ADD CONSTRAINT seats_trainnumber_fkey FOREIGN KEY (trainnumber) REFERENCES traininfo(trainnumber);


--
-- Name: public; Type: ACL; Schema: -; Owner: omm
--

REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON SCHEMA public FROM omm;
GRANT CREATE,USAGE ON SCHEMA public TO omm;
GRANT USAGE ON SCHEMA public TO PUBLIC;


--
-- Name: add_passenger(character varying, character varying, character varying, passenger_type); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) FROM PUBLIC;
REVOKE ALL ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) FROM jxz;
GRANT EXECUTE ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO jxz;
GRANT EXECUTE ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO PUBLIC;
GRANT EXECUTE ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO zyy;
GRANT EXECUTE ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO zlz;
GRANT EXECUTE ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION add_passenger(users_account character varying, id character varying, telenum character varying, pt passenger_type) TO lz;


--
-- Name: cancel_unpaid_orders(integer); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION cancel_unpaid_orders(orders_number integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION cancel_unpaid_orders(orders_number integer) FROM jxz;
GRANT EXECUTE ON FUNCTION cancel_unpaid_orders(orders_number integer) TO jxz;
GRANT EXECUTE ON FUNCTION cancel_unpaid_orders(orders_number integer) TO PUBLIC;
GRANT EXECUTE ON FUNCTION cancel_unpaid_orders(orders_number integer) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION cancel_unpaid_orders(orders_number integer) TO zyy;
GRANT EXECUTE ON FUNCTION cancel_unpaid_orders(orders_number integer) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION cancel_unpaid_orders(orders_number integer) TO zlz;
GRANT EXECUTE ON FUNCTION cancel_unpaid_orders(orders_number integer) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION cancel_unpaid_orders(orders_number integer) TO lz;


--
-- Name: get_available_seats(character varying); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION get_available_seats(p_train_id character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_available_seats(p_train_id character varying) FROM jxz;
GRANT EXECUTE ON FUNCTION get_available_seats(p_train_id character varying) TO jxz;
GRANT EXECUTE ON FUNCTION get_available_seats(p_train_id character varying) TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_available_seats(p_train_id character varying) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_available_seats(p_train_id character varying) TO zyy;
GRANT EXECUTE ON FUNCTION get_available_seats(p_train_id character varying) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_available_seats(p_train_id character varying) TO zlz;
GRANT EXECUTE ON FUNCTION get_available_seats(p_train_id character varying) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_available_seats(p_train_id character varying) TO lz;


--
-- Name: get_available_seats_for_train(character varying); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION get_available_seats_for_train(p_train_id character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_available_seats_for_train(p_train_id character varying) FROM jxz;
GRANT EXECUTE ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO jxz;
GRANT EXECUTE ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO zyy;
GRANT EXECUTE ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO zlz;
GRANT EXECUTE ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_available_seats_for_train(p_train_id character varying) TO lz;


--
-- Name: get_passenger_names_and_ids(character varying); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION get_passenger_names_and_ids(users_account character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION get_passenger_names_and_ids(users_account character varying) FROM jxz;
GRANT EXECUTE ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO jxz;
GRANT EXECUTE ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO PUBLIC;
GRANT EXECUTE ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO zyy;
GRANT EXECUTE ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO zlz;
GRANT EXECUTE ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION get_passenger_names_and_ids(users_account character varying) TO lz;


--
-- Name: refund_orders(integer); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION refund_orders(p_orders_number integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION refund_orders(p_orders_number integer) FROM jxz;
GRANT EXECUTE ON FUNCTION refund_orders(p_orders_number integer) TO jxz;
GRANT EXECUTE ON FUNCTION refund_orders(p_orders_number integer) TO PUBLIC;
GRANT EXECUTE ON FUNCTION refund_orders(p_orders_number integer) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION refund_orders(p_orders_number integer) TO zyy;
GRANT EXECUTE ON FUNCTION refund_orders(p_orders_number integer) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION refund_orders(p_orders_number integer) TO zlz;
GRANT EXECUTE ON FUNCTION refund_orders(p_orders_number integer) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION refund_orders(p_orders_number integer) TO lz;


--
-- Name: show_all_unpaid_orders(character varying); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION show_all_unpaid_orders(user_account character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION show_all_unpaid_orders(user_account character varying) FROM jxz;
GRANT EXECUTE ON FUNCTION show_all_unpaid_orders(user_account character varying) TO jxz;
GRANT EXECUTE ON FUNCTION show_all_unpaid_orders(user_account character varying) TO PUBLIC;
GRANT EXECUTE ON FUNCTION show_all_unpaid_orders(user_account character varying) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION show_all_unpaid_orders(user_account character varying) TO zyy;
GRANT EXECUTE ON FUNCTION show_all_unpaid_orders(user_account character varying) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION show_all_unpaid_orders(user_account character varying) TO zlz;
GRANT EXECUTE ON FUNCTION show_all_unpaid_orders(user_account character varying) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION show_all_unpaid_orders(user_account character varying) TO lz;


--
-- Name: show_all_untraveled_orders(character varying); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION show_all_untraveled_orders(user_account character varying) FROM PUBLIC;
REVOKE ALL ON FUNCTION show_all_untraveled_orders(user_account character varying) FROM jxz;
GRANT EXECUTE ON FUNCTION show_all_untraveled_orders(user_account character varying) TO jxz;
GRANT EXECUTE ON FUNCTION show_all_untraveled_orders(user_account character varying) TO PUBLIC;
GRANT EXECUTE ON FUNCTION show_all_untraveled_orders(user_account character varying) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION show_all_untraveled_orders(user_account character varying) TO zyy;
GRANT EXECUTE ON FUNCTION show_all_untraveled_orders(user_account character varying) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION show_all_untraveled_orders(user_account character varying) TO zlz;
GRANT EXECUTE ON FUNCTION show_all_untraveled_orders(user_account character varying) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION show_all_untraveled_orders(user_account character varying) TO lz;


--
-- Name: transfer_orders(character varying, integer, integer, integer, time without time zone, time without time zone); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) FROM PUBLIC;
REVOKE ALL ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) FROM jxz;
GRANT EXECUTE ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO jxz;
GRANT EXECUTE ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO PUBLIC;
GRANT EXECUTE ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO zyy;
GRANT EXECUTE ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO zlz;
GRANT EXECUTE ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION transfer_orders(p_train_id character varying, p_orders_number integer, p_carriage_number integer, p_seat_number integer, p_start_time time without time zone, p_end_time time without time zone) TO lz;


--
-- Name: update_orders(); Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON FUNCTION update_orders() FROM PUBLIC;
REVOKE ALL ON FUNCTION update_orders() FROM jxz;
GRANT EXECUTE ON FUNCTION update_orders() TO jxz;
GRANT EXECUTE ON FUNCTION update_orders() TO PUBLIC;
GRANT EXECUTE ON FUNCTION update_orders() TO zyy;
GRANT ALTER,DROP,COMMENT ON FUNCTION update_orders() TO zyy;
GRANT EXECUTE ON FUNCTION update_orders() TO zlz;
GRANT ALTER,DROP,COMMENT ON FUNCTION update_orders() TO zlz;
GRANT EXECUTE ON FUNCTION update_orders() TO lz;
GRANT ALTER,DROP,COMMENT ON FUNCTION update_orders() TO lz;


--
-- Name: seats; Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON TABLE seats FROM PUBLIC;
REVOKE ALL ON TABLE seats FROM jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE seats TO jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE seats TO zyy;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE seats TO zyy;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE seats TO zlz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE seats TO zlz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE seats TO lz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE seats TO lz;


--
-- Name: station; Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON TABLE station FROM PUBLIC;
REVOKE ALL ON TABLE station FROM jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE station TO jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE station TO zyy;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE station TO zyy;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE station TO zlz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE station TO zlz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE station TO lz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE station TO lz;


--
-- Name: traininfo; Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON TABLE traininfo FROM PUBLIC;
REVOKE ALL ON TABLE traininfo FROM jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE traininfo TO jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE traininfo TO zyy;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE traininfo TO zyy;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE traininfo TO zlz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE traininfo TO zlz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE traininfo TO lz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE traininfo TO lz;


--
-- Name: users; Type: ACL; Schema: public; Owner: jxz
--

REVOKE ALL ON TABLE users FROM PUBLIC;
REVOKE ALL ON TABLE users FROM jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE users TO jxz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE users TO zyy;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE users TO zyy;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE users TO zlz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE users TO zlz;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE users TO lz;
GRANT COMMENT,ALTER,DROP,INDEX,VACUUM ON TABLE users TO lz;


--
-- openGauss database dump complete
--

