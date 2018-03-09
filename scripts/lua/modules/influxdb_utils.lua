local os_utils = require "os_utils"
require "lua_utils"
local json = require ("dkjson")

local influxdb_utils = {}
local size = 5

--------------------------------------------------------------------------------
local function create_db(name)
  if(enable_second_debug == 1) then io.write('Creating InfluxDB ', name, '\n') end
  local url = "http://localhost:8086/query?q=CREATE+DATABASE+"..name
  ntop.postHTTP("","",url)
end
-- ########################################################
local function update_db(name, batch)
  local url = "http://localhost:8086/write?db="..name
  ntop.postHTTPBinaryData("", "", url, batch)
end
-- ########################################################
local function reset(file_path)
  batch_file = io.open(file_path,"w") 
  batch_file:close()
end

function influxdb_utils.makeInfluxDB(basedir, name, timestamp, measurements)
  local batch_path = os_utils.fixPath(basedir .. "/batch")
  local counter = ntop.getCounter()
  local db_name = "iface_"..name
  batch_file = io.open(batch_path,"a")
  if(counter == 0) then 
    create_db(db_name)
  elseif(counter == size) then
    if(enable_second_debug == 1) then io.write('Updating database '.."iface_"..db_name..'\n') end
    update_db(db_name, batch_path)
    reset(batch_path)
    ntop.resetCounter()
  else
    for m,v in pairs(measurements) do
      --local point = m.." value="..v.." "..tostring(timestamp)
      local point = m.." value="..v
      if(enable_second_debug == 1) then io.write('Batching points to '..db_name..'\n') end
      batch_file:write(point.."\n")
    end
  end
  ntop.incrementCounter()
end

-- ########################################################
function influxdb_utils.queryDB(name, measurement)
  local url = "http://localhost:8086/query?pretty=true&db="..name.."&q=SELECT+*+FROM+"..measurement
  local response = ntop.httpGet(url)
  return response["CONTENT"]
end
-- ########################################################

return influxdb_utils
