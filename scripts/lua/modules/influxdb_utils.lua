local os_utils = require "os_utils"
require "lua_utils"
local json = require ("dkjson")

local influxdb_utils = {}
local size = 5

--------------------------------------------------------------------------------
local function create_db()
  if(enable_second_debug == 1) then io.write('Creating InfluxDB database', '\n') end
  local url = "http://localhost:8086/query?q=CREATE+DATABASE+ntopng"
  ntop.postHTTP("","",url)
end
-- ########################################################
local function update_db(batch)
  local url = "http://localhost:8086/write?db=ntopng"
  ntop.postHTTPBinaryData("", "", url, batch)
end
-- ########################################################
local function reset(file_path)
  batch_file = io.open(file_path,"w") 
  batch_file:close()
end

-- ########################################################
function influxdb_utils.makeInfluxDB(basedir, ifid, measurements)
  local batch_path = os_utils.fixPath(basedir .. "/batch")
  local counter = ntop.getCounter()
  batch_file = io.open(batch_path,"a")
  if(counter == 0) then 
    create_db()
  elseif(counter == size) then
    if(enable_second_debug == 1) then io.write('Updating database...\n') end
    update_db(batch_path)
    reset(batch_path)
    ntop.resetCounter()
  else
    if(enable_second_debug == 1) then io.write('Batching points..\n') end
    for m,v in pairs(measurements) do
      local point = m..",ifid="..ifid.." value="..v
      batch_file:write(point.."\n")
    end
  end
  ntop.incrementCounter()
end
-- ########################################################
function influxdb_utils.queryDB(measurement)
  local url = "http://localhost:8086/query?pretty=true&db=ntopng&q=SELECT+*+FROM+"..measurement
  local response = ntop.httpGet(url)
  return response["CONTENT"]
end
-- ########################################################

return influxdb_utils
