
-record(bitmex, { table=[], action=[], data=[], keys=[], types=[], attributes=[], foreignKeys=[] }).
-record(sym,  { id=[], symbol=[], side=[], size=[], price=[] }). % bitmex.data : list(sym)

