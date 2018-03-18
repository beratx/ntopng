local os_utils = require "os_utils"
require "lua_utils"
local json = require ("dkjson")

local influxdb_utils = {}
local size = 5

--------------------------------------------------------------------------------

local function url_encode(str)
   if (str) then
     str = string.gsub (str, "\n", "\r\n")
     str = string.gsub (str, "([^%w %-%_%.%~])",
         function (c) return string.format ("%%%02X", string.byte(c)) end)
     str = string.gsub (str, " ", "+")
   end
   return str	
end

-- ########################################################

local function exist_db(db)
  local url = "http://localhost:8086/query?q=SHOW+DATABASES"
  local resp = ntop.httpGet(url,"","",10)
  local obj,pos,err = json.decode(resp["CONTENT"],1,nil)

  if(not(err)) then
   local names = obj["results"][1]["series"][1]["values"]
   for i=1,#names do
     if(string.match(db,names[i][1])) then 
       return true 
     end
   end
  end

  return false
end

-- ########################################################

local function continuous_query(name, rp, measurement, time)
  return "CREATE CONTINUOUS QUERY "..name.." ON \"ntopng\" BEGIN SELECT mean(\"value\") AS \"mean_value\" INTO "..rp.."."..measurement.." FROM \"bytes\" GROUP BY time("..time..") END"
end

-- ########################################################

local function retention_policy(name, duration, default)
  if default then
    return "CREATE+RETENTION+POLICY+"..name.."+ON+ntopng+DURATION+"..duration.."+REPLICATION+1+DEFAULT"
  else
    return "CREATE+RETENTION+POLICY+"..name.."+ON+ntopng+DURATION+"..duration.."+REPLICATION+1"
  end

end

-- ########################################################

local function create_db()
  if(enable_second_debug == 1) then io.write('Creating InfluxDB database', '\n') end

  local base_url = "http://localhost:8086/query?q="

  --create database
  local create = base_url.."CREATE+DATABASE+ntopng"
  ntop.postHTTP("","",create)

  --create retention policies
  local rp_default = retention_policy("one_day", "1d", true)
  local rp_1 = retention_policy("one_month", "4w", false)
  local rp_2 = retention_policy("hundred_days", "100d", false)
  local rp_3 = retention_policy("one_year", "52w", false)

  ntop.postHTTP("","",base_url..rp_default)
  ntop.postHTTP("","",base_url..rp_1)
  ntop.postHTTP("","",base_url..rp_2)
  ntop.postHTTP("","",base_url..rp_3)

  --create continuous queries
  local cq_1m_raw = continuous_query("cq_1m","one_month","one_min_bytes","1m")
  local cq_1h_raw = continuous_query("cq_1h","hundred_days","one_hour_bytes","1h")
  local cq_1d_raw = continuous_query("cq_1d","one_year","one_day_bytes","1d")

  ntop.postHTTP("","",base_url..url_encode(cq_1m_raw))
  ntop.postHTTP("","",base_url..url_encode(cq_1h_raw))
  ntop.postHTTP("","",base_url..url_encode(cq_1d_raw))
end

-- ########################################################

local function update_db(batch)
  --default precision is nanoseconds
  local url = "http://localhost:8086/write?db=ntopng&precision=s"
  ntop.postHTTPBinaryData("", "", url, batch)
end

-- ########################################################

local function reset(file_path)
  batch_file = io.open(file_path,"w") 
  batch_file:close()
end

-- ########################################################

function influxdb_utils.makeInfluxDB(basedir, ifid, measurements,when)
  local batch_path = os_utils.fixPath(basedir .. "/batch")
  local counter = ntop.getCounter()
  batch_file = io.open(batch_path,"a")
  if((counter == 0) and not(exist_db("ntopng"))) then 
    create_db()
  elseif(counter == size) then
    if(enable_second_debug == 1) then io.write('Updating database...\n') end
    update_db(batch_path)
    reset(batch_path)
    ntop.resetCounter()
  else
    if(enable_second_debug == 1) then io.write('Batching points..\n') end
    for m,v in pairs(measurements) do
      local point = m..",ifid="..ifid.." value="..v.." "..when
      batch_file:write(point.."\n")
    end
  end
  ntop.incrementCounter()
end

-- ########################################################
function influxdb_utils.queryDB(ifid,fields,measurement,start_time,end_time)
  local url ="http://localhost:8086/query?db=ntopng&epoch=s&q=SELECT+"..fields.."+FROM+"..measurement.."+"
  local condition = "WHERE ifid = \'"..ifid.."\' and time >= "..start_time.." and time <= "..end_time
  local response = ntop.httpGet(url..url_encode(condition))
  return response["CONTENT"]
end
-- ########################################################

return influxdb_utils
