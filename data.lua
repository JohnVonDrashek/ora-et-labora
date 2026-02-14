local Data = {}

-------------------------------------------------------------------------------
-- WORK TYPES (replaces Genres)
-- The primary form of work the monastery produces
-- Stats: devotion, wisdom, beauty, harmony
-------------------------------------------------------------------------------
Data.genres = {
    {name = "Manuscript",       stats = {fun=1.2, creativity=1.0, graphics=1.2, sound=0.8}},
    {name = "Herbal Remedy",    stats = {fun=0.8, creativity=1.3, graphics=0.7, sound=0.9}},
    {name = "Sacred Music",     stats = {fun=1.0, creativity=0.9, graphics=0.6, sound=1.4}},
    {name = "Ale & Mead",       stats = {fun=1.3, creativity=0.7, graphics=0.7, sound=0.8}},
    {name = "Stone Carving",    stats = {fun=0.9, creativity=0.8, graphics=1.4, sound=0.7}},
    {name = "Theology",         stats = {fun=1.1, creativity=1.3, graphics=0.7, sound=0.9}},
    {name = "Prayer Book",      stats = {fun=1.2, creativity=1.0, graphics=1.0, sound=1.0}},
    {name = "Chronicle",        stats = {fun=0.8, creativity=1.2, graphics=0.9, sound=0.8}},
    {name = "Icon Painting",    stats = {fun=1.0, creativity=1.0, graphics=1.3, sound=0.8}},
    {name = "Vestments",        stats = {fun=0.9, creativity=1.0, graphics=1.2, sound=0.7}},
}

-------------------------------------------------------------------------------
-- SUBJECTS (replaces Types)
-- The thematic subject of the work
-------------------------------------------------------------------------------
Data.types = {
    {name = "Saints' Lives",    stats = {fun=1.1, creativity=1.1, graphics=1.0, sound=0.9}},
    {name = "Gospel",           stats = {fun=1.2, creativity=1.0, graphics=1.0, sound=1.1}},
    {name = "Psalms",           stats = {fun=1.0, creativity=0.9, graphics=0.9, sound=1.3}},
    {name = "Natural Philosophy", stats = {fun=0.8, creativity=1.3, graphics=1.0, sound=0.8}},
    {name = "History",          stats = {fun=0.9, creativity=1.2, graphics=0.9, sound=0.8}},
    {name = "Liturgy",          stats = {fun=1.1, creativity=0.9, graphics=1.0, sound=1.2}},
    {name = "Medicine",         stats = {fun=0.8, creativity=1.2, graphics=0.8, sound=0.8}},
    {name = "Astronomy",        stats = {fun=0.9, creativity=1.1, graphics=1.1, sound=0.7}},
    {name = "Scripture",        stats = {fun=1.2, creativity=1.0, graphics=1.1, sound=1.0}},
    {name = "Poetry",           stats = {fun=1.0, creativity=1.2, graphics=0.8, sound=1.1}},
    {name = "Patristics",       stats = {fun=1.1, creativity=1.2, graphics=0.7, sound=0.9}},
    {name = "Rule of Life",     stats = {fun=1.0, creativity=1.0, graphics=0.8, sound=0.9}},
    {name = "Herbalism",        stats = {fun=0.9, creativity=1.1, graphics=1.0, sound=0.7}},
    {name = "Chant",            stats = {fun=1.0, creativity=0.8, graphics=0.6, sound=1.4}},
    {name = "Feast Days",       stats = {fun=1.3, creativity=0.9, graphics=1.1, sound=1.1}},
    {name = "Martyrology",      stats = {fun=1.0, creativity=1.1, graphics=0.9, sound=0.8}},
    {name = "Architecture",     stats = {fun=0.8, creativity=1.0, graphics=1.3, sound=0.6}},
    {name = "Morality",         stats = {fun=1.1, creativity=1.1, graphics=0.7, sound=0.9}},
    {name = "Pilgrimage",       stats = {fun=1.1, creativity=1.0, graphics=1.0, sound=1.0}},
    {name = "Creation",         stats = {fun=1.0, creativity=1.1, graphics=1.2, sound=0.9}},
}

-------------------------------------------------------------------------------
-- WORK/SUBJECT COMPATIBILITY  (5=perfect, 4=great, 3=good, 2=ok, 1=poor)
-------------------------------------------------------------------------------
Data.compatibility = {}
local function setCompat(genre, typ, val)
    Data.compatibility[genre .. "_" .. typ] = val
end
-- Manuscript combos
setCompat("Manuscript","Gospel",5)        setCompat("Manuscript","Scripture",5)
setCompat("Manuscript","Saints' Lives",4) setCompat("Manuscript","Psalms",4)
setCompat("Manuscript","History",3)       setCompat("Manuscript","Poetry",3)
setCompat("Manuscript","Patristics",3)    setCompat("Manuscript","Liturgy",3)
-- Herbal Remedy combos
setCompat("Herbal Remedy","Medicine",5)   setCompat("Herbal Remedy","Herbalism",5)
setCompat("Herbal Remedy","Natural Philosophy",4)
setCompat("Herbal Remedy","Creation",3)   setCompat("Herbal Remedy","Pilgrimage",3)
-- Sacred Music combos
setCompat("Sacred Music","Chant",5)       setCompat("Sacred Music","Psalms",5)
setCompat("Sacred Music","Liturgy",4)     setCompat("Sacred Music","Feast Days",4)
setCompat("Sacred Music","Poetry",3)      setCompat("Sacred Music","Gospel",3)
-- Ale & Mead combos
setCompat("Ale & Mead","Feast Days",5)    setCompat("Ale & Mead","Herbalism",4)
setCompat("Ale & Mead","Pilgrimage",4)    setCompat("Ale & Mead","Rule of Life",3)
setCompat("Ale & Mead","Creation",3)
-- Stone Carving combos
setCompat("Stone Carving","Architecture",5) setCompat("Stone Carving","Saints' Lives",4)
setCompat("Stone Carving","Scripture",4)    setCompat("Stone Carving","Creation",4)
setCompat("Stone Carving","Martyrology",3)  setCompat("Stone Carving","Gospel",3)
-- Theology combos
setCompat("Theology","Patristics",5)      setCompat("Theology","Scripture",5)
setCompat("Theology","Gospel",4)          setCompat("Theology","Morality",4)
setCompat("Theology","Natural Philosophy",3) setCompat("Theology","History",3)
-- Prayer Book combos
setCompat("Prayer Book","Liturgy",5)      setCompat("Prayer Book","Psalms",5)
setCompat("Prayer Book","Saints' Lives",4) setCompat("Prayer Book","Feast Days",4)
setCompat("Prayer Book","Gospel",3)       setCompat("Prayer Book","Rule of Life",3)
-- Chronicle combos
setCompat("Chronicle","History",5)        setCompat("Chronicle","Pilgrimage",5)
setCompat("Chronicle","Martyrology",4)    setCompat("Chronicle","Saints' Lives",4)
setCompat("Chronicle","Natural Philosophy",3)
-- Icon Painting combos
setCompat("Icon Painting","Saints' Lives",5) setCompat("Icon Painting","Gospel",5)
setCompat("Icon Painting","Scripture",4)     setCompat("Icon Painting","Feast Days",4)
setCompat("Icon Painting","Creation",4)      setCompat("Icon Painting","Liturgy",3)
-- Vestments combos
setCompat("Vestments","Liturgy",5)        setCompat("Vestments","Feast Days",5)
setCompat("Vestments","Saints' Lives",4)  setCompat("Vestments","Architecture",3)
setCompat("Vestments","Pilgrimage",3)

function Data.getCompatibility(genre, typ)
    return Data.compatibility[genre .. "_" .. typ] or 2
end

-------------------------------------------------------------------------------
-- PATRONS (replaces Platforms)
-- year = when they become available, cost = gift/tithe to gain patronage
-- share = reach/influence multiplier
-------------------------------------------------------------------------------
Data.platforms = {
    {name = "Local Parish",      year = 1,  cost = 0,      share = 0.20, maxYear = 99, color = {0.55,0.45,0.35}},
    {name = "Town Market",       year = 1,  cost = 15000,  share = 0.30, maxYear = 8,  color = {0.6,0.5,0.3}},
    {name = "Bishop's See",      year = 2,  cost = 30000,  share = 0.35, maxYear = 12, color = {0.6,0.2,0.6}},
    {name = "Noble Court",       year = 3,  cost = 50000,  share = 0.40, maxYear = 14, color = {0.2,0.4,0.7}},
    {name = "Pilgrim Route",     year = 4,  cost = 40000,  share = 0.35, maxYear = 15, color = {0.5,0.6,0.3}},
    {name = "University",        year = 6,  cost = 80000,  share = 0.40, maxYear = 20, color = {0.3,0.3,0.6}},
    {name = "Cathedral",         year = 7,  cost = 100000, share = 0.45, maxYear = 20, color = {0.7,0.6,0.2}},
    {name = "Royal Court",       year = 9,  cost = 150000, share = 0.50, maxYear = 18, color = {0.7,0.15,0.15}},
    {name = "Trade Guild",       year = 5,  cost = 60000,  share = 0.35, maxYear = 16, color = {0.5,0.35,0.2}},
    {name = "Monastery Network", year = 8,  cost = 80000,  share = 0.40, maxYear = 20, color = {0.35,0.25,0.15}},
    {name = "Archbishop",        year = 11, cost = 120000, share = 0.45, maxYear = 20, color = {0.5,0.1,0.5}},
    {name = "Imperial Court",    year = 13, cost = 200000, share = 0.50, maxYear = 20, color = {0.8,0.65,0.1}},
    {name = "Papal Court",       year = 15, cost = 250000, share = 0.55, maxYear = 20, color = {0.9,0.85,0.6}},
    {name = "Grand Library",     year = 10, cost = 100000, share = 0.40, maxYear = 20, color = {0.4,0.3,0.2}},
    {name = "Foreign Mission",   year = 16, cost = 180000, share = 0.45, maxYear = 20, color = {0.2,0.5,0.4}},
    {name = "Ecumenical Council",year = 18, cost = 300000, share = 0.55, maxYear = 20, color = {0.9,0.9,0.7}},
}

-------------------------------------------------------------------------------
-- APPEARANCE COLORS for monk character generation
-------------------------------------------------------------------------------
Data.hairColors = {
    {0.15, 0.10, 0.05},  -- dark brown
    {0.05, 0.05, 0.05},  -- black
    {0.55, 0.35, 0.15},  -- light brown
    {0.80, 0.65, 0.20},  -- blonde
    {0.60, 0.15, 0.10},  -- red
    {0.45, 0.45, 0.50},  -- gray
}
Data.skinColors = {
    {0.96, 0.84, 0.72},  -- light
    {0.87, 0.72, 0.53},  -- medium
    {0.76, 0.60, 0.42},  -- tan
    {0.55, 0.38, 0.26},  -- brown
    {0.40, 0.28, 0.18},  -- dark brown
}
-- Robe colors (monastic orders)
Data.shirtColors = {
    {0.12, 0.10, 0.08},  -- Benedictine black
    {0.90, 0.87, 0.80},  -- Cistercian white
    {0.35, 0.25, 0.15},  -- Franciscan brown
    {0.20, 0.18, 0.15},  -- Augustinian dark
    {0.45, 0.42, 0.38},  -- undyed gray
    {0.55, 0.48, 0.35},  -- natural wool
    {0.25, 0.22, 0.18},  -- dark brown
    {0.65, 0.60, 0.52},  -- light gray
    {0.30, 0.28, 0.25},  -- charcoal
    {0.50, 0.45, 0.35},  -- earth tone
}
-- Cord/belt colors
Data.pantsColors = {
    {0.55, 0.45, 0.30},  -- rope brown
    {0.20, 0.18, 0.15},  -- dark cord
    {0.65, 0.55, 0.40},  -- light rope
    {0.40, 0.30, 0.20},  -- leather brown
    {0.30, 0.25, 0.18},  -- dark leather
}

-------------------------------------------------------------------------------
-- MONK POOL (available brothers/sisters for the monastery)
-- Stats: faith(program), scholarship(scenario), artistry(graphics), craftsmanship(sound)
-------------------------------------------------------------------------------
Data.staffPool = {
    {name="Br. Thomas",  job="Scribe",       stats={program=40, scenario=15, graphics=10, sound=10}, speed=30, salary=3000,  level=1},
    {name="Br. Anselm",  job="Scribe",       stats={program=50, scenario=20, graphics=15, sound=10}, speed=35, salary=4500,  level=2},
    {name="Br. Cuthbert", job="Illuminator",  stats={program=15, scenario=25, graphics=45, sound=15}, speed=28, salary=3500,  level=1},
    {name="Sr. Hildegard",job="Illuminator",  stats={program=10, scenario=20, graphics=55, sound=20}, speed=32, salary=5000,  level=2},
    {name="Br. Bede",    job="Scholar",       stats={program=10, scenario=50, graphics=10, sound=15}, speed=25, salary=3000,  level=1},
    {name="Sr. Julian",  job="Scholar",       stats={program=15, scenario=60, graphics=15, sound=20}, speed=30, salary=4500,  level=2},
    {name="Br. Ambrose", job="Cantor",        stats={program=15, scenario=15, graphics=10, sound=50}, speed=28, salary=3500,  level=1},
    {name="Sr. Cecilia",  job="Cantor",       stats={program=10, scenario=20, graphics=15, sound=60}, speed=35, salary=5000,  level=2},
    {name="Br. Benedict", job="Scribe",       stats={program=65, scenario=25, graphics=20, sound=15}, speed=40, salary=7000,  level=3},
    {name="Br. Alcuin",  job="Illuminator",   stats={program=20, scenario=30, graphics=70, sound=20}, speed=38, salary=7500,  level=3},
    {name="Br. Columba",  job="Cellarer",     stats={program=30, scenario=40, graphics=30, sound=30}, speed=35, salary=6000,  level=2},
    {name="Fr. Dominic",  job="Prior",        stats={program=25, scenario=50, graphics=35, sound=35}, speed=30, salary=8000,  level=3},
    {name="Br. Caedmon",  job="Scribe",       stats={program=80, scenario=15, graphics=10, sound=10}, speed=45, salary=9000,  level=4},
    {name="Br. Aidan",    job="Bookbinder",   stats={program=90, scenario=10, graphics=10, sound=10}, speed=50, salary=10000, level=5},
    {name="Fr. Augustine",job="Cellarer",     stats={program=40, scenario=50, graphics=40, sound=40}, speed=40, salary=9500,  level=4},
    {name="Sr. Teresa",   job="Scholar",      stats={program=10, scenario=80, graphics=20, sound=25}, speed=35, salary=8000,  level=4},
    {name="Br. Gregory",  job="Cantor",       stats={program=15, scenario=25, graphics=15, sound=85}, speed=40, salary=9000,  level=4},
    {name="Br. Dunstan",  job="Brewmaster",   stats={program=50, scenario=10, graphics=20, sound=15}, speed=30, salary=6500,  level=3},
    {name="Sr. Brigid",   job="Illuminator",  stats={program=10, scenario=35, graphics=90, sound=25}, speed=42, salary=10000, level=5},
    {name="Fr. Aquinas",  job="Prior",        stats={program=40, scenario=70, graphics=50, sound=50}, speed=38, salary=13000, level=5},
    {name="Br. Simeon",   job="Scribe",       stats={program=35, scenario=20, graphics=15, sound=10}, speed=25, salary=2500,  level=1},
    {name="Br. Placid",   job="Illuminator",  stats={program=10, scenario=15, graphics=35, sound=10}, speed=22, salary=2500,  level=1},
    {name="Sr. Scholastica",job="Scholar",    stats={program=10, scenario=35, graphics=10, sound=10}, speed=20, salary=2000,  level=1},
    {name="Br. Odo",      job="Cantor",       stats={program=10, scenario=10, graphics=10, sound=35}, speed=22, salary=2500,  level=1},
    {name="Br. Wilfrid",  job="Scribe",       stats={program=55, scenario=20, graphics=15, sound=15}, speed=32, salary=5500,  level=2},
    {name="Br. Maurus",   job="Cellarer",     stats={program=25, scenario=35, graphics=25, sound=25}, speed=28, salary=4000,  level=1},
    {name="Fr. Bernard",  job="Prior",        stats={program=30, scenario=45, graphics=30, sound=30}, speed=32, salary=6500,  level=2},
    {name="Br. Basil",    job="Bookbinder",   stats={program=70, scenario=10, graphics=10, sound=10}, speed=42, salary=7000,  level=3},
    {name="Br. Isidore",  job="Brewmaster",   stats={program=45, scenario=15, graphics=25, sound=20}, speed=28, salary=5000, level=2},
    {name="Br. Colm",     job="Illuminator",  stats={program=15, scenario=25, graphics=60, sound=15}, speed=35, salary=6000,  level=3},
}

Data.jobTypes = {
    "Scribe", "Illuminator", "Scholar", "Cantor", "Cellarer", "Prior", "Bookbinder", "Brewmaster"
}

-- Vocation bonuses (stat multipliers during work)
Data.jobBonuses = {
    ["Scribe"]       = {program=1.5, scenario=0.8, graphics=0.6, sound=0.6},
    ["Illuminator"]  = {program=0.6, scenario=0.9, graphics=1.5, sound=0.7},
    ["Scholar"]      = {program=0.7, scenario=1.5, graphics=0.6, sound=0.8},
    ["Cantor"]       = {program=0.7, scenario=0.7, graphics=0.6, sound=1.5},
    ["Cellarer"]     = {program=1.0, scenario=1.1, graphics=1.0, sound=1.0},
    ["Prior"]        = {program=0.9, scenario=1.3, graphics=1.0, sound=1.0},
    ["Bookbinder"]   = {program=1.8, scenario=0.5, graphics=0.5, sound=0.5},
    ["Brewmaster"]   = {program=1.3, scenario=0.6, graphics=0.8, sound=0.7},
}

-------------------------------------------------------------------------------
-- FORMATION (replaces Training)
-------------------------------------------------------------------------------
Data.training = {
    {name = "Lectio Divina",     cost = 6000,  stat = "program",   amount = 8,  weeks = 4},
    {name = "Art of Gilding",    cost = 7000,  stat = "graphics",  amount = 8,  weeks = 4},
    {name = "Theological Study", cost = 7000,  stat = "scenario",  amount = 8,  weeks = 4},
    {name = "Gregorian Chant",   cost = 6000,  stat = "sound",     amount = 8,  weeks = 4},
    {name = "Monastic Retreat",  cost = 12000, stat = "all",       amount = 4,  weeks = 6},
    {name = "Pilgrimage",        cost = 25000, stat = "random",    amount = 20, weeks = 8},
    {name = "Copyist Workshop",  cost = 4000,  stat = "speed",     amount = 6,  weeks = 2},
    {name = "Scriptorium Master",cost = 10000, stat = "program",   amount = 15, weeks = 3},
}

-------------------------------------------------------------------------------
-- PROVISIONS (replaces Items, usable during work to boost production)
-------------------------------------------------------------------------------
Data.items = {
    {name = "Monastery Ale",    cost = 800,   effect = "speed",    amount = 20,  desc = "Boost work speed"},
    {name = "Ancient Texts",    cost = 2500,  effect = "program",  amount = 30,  desc = "+30 to faith"},
    {name = "Rare Pigments",    cost = 2500,  effect = "graphics", amount = 30,  desc = "+30 to beauty"},
    {name = "Bell Set",         cost = 2500,  effect = "sound",    amount = 30,  desc = "+30 to harmony"},
    {name = "Holy Relic",       cost = 3000,  effect = "scenario", amount = 30,  desc = "+30 to wisdom"},
    {name = "Magnifying Glass", cost = 4000,  effect = "bugs",     amount = -40, desc = "Fix 40 errors"},
    {name = "Town Crier",       cost = 6000,  effect = "hype",     amount = 50,  desc = "+50% distribution"},
    {name = "Pilgrim Route Map",cost = 1500,  effect = "fans",     amount = 5000, desc = "+5000 renown"},
}

-------------------------------------------------------------------------------
-- COMMISSIONS (replaces Contracts - small paid work)
-------------------------------------------------------------------------------
Data.contracts = {
    {name = "Copy Parish Records",  pay = 4000,   weeks = 2, minStaff = 1},
    {name = "Brew Festival Ale",    pay = 6000,   weeks = 3, minStaff = 1},
    {name = "Repair Old Texts",     pay = 8000,   weeks = 2, minStaff = 2},
    {name = "Design Coat of Arms",  pay = 3000,   weeks = 1, minStaff = 1},
    {name = "Compose Hymn",         pay = 5000,   weeks = 2, minStaff = 1},
    {name = "Translate Scripture",   pay = 10000,  weeks = 3, minStaff = 2},
    {name = "Build Shrine",         pay = 12000,  weeks = 4, minStaff = 2},
    {name = "Illuminate Bible",     pay = 20000,  weeks = 5, minStaff = 3},
    {name = "Catalog Library",      pay = 35000,  weeks = 6, minStaff = 3},
    {name = "Create Altarpiece",    pay = 45000,  weeks = 8, minStaff = 4},
}

-------------------------------------------------------------------------------
-- STUDIES (replaces Research - unlock new work types/subjects)
-------------------------------------------------------------------------------
Data.researchGenres = {
    {name = "Astronomy Text",  stats = {fun=0.9, creativity=1.3, graphics=0.8, sound=0.7}, cost = 40000, yearReq = 3},
    {name = "Bestiary",        stats = {fun=1.1, creativity=1.1, graphics=1.2, sound=0.7}, cost = 35000, yearReq = 2},
    {name = "Bell Casting",    stats = {fun=0.9, creativity=0.8, graphics=0.8, sound=1.4}, cost = 45000, yearReq = 4},
    {name = "Metalwork",       stats = {fun=0.9, creativity=0.8, graphics=1.3, sound=0.8}, cost = 30000, yearReq = 2},
    {name = "Herbarium",       stats = {fun=0.8, creativity=1.2, graphics=1.1, sound=0.7}, cost = 25000, yearReq = 1},
    {name = "Grand Cathedral", stats = {fun=1.1, creativity=1.1, graphics=1.1, sound=1.1}, cost = 100000,yearReq = 10},
}

Data.researchTypes = {
    {name = "Apocalypse",     stats = {fun=1.0, creativity=1.2, graphics=1.1, sound=1.0}, cost = 20000, yearReq = 2},
    {name = "Angels",         stats = {fun=1.1, creativity=1.0, graphics=1.2, sound=1.0}, cost = 25000, yearReq = 3},
    {name = "Cosmology",      stats = {fun=0.9, creativity=1.3, graphics=1.0, sound=0.8}, cost = 30000, yearReq = 4},
    {name = "Monasticism",    stats = {fun=1.1, creativity=1.1, graphics=0.9, sound=0.9}, cost = 15000, yearReq = 1},
    {name = "Miracles",       stats = {fun=1.2, creativity=1.0, graphics=1.0, sound=1.0}, cost = 35000, yearReq = 5},
    {name = "Philosophy",     stats = {fun=0.8, creativity=1.4, graphics=0.7, sound=0.8}, cost = 50000, yearReq = 8},
    {name = "Agriculture",    stats = {fun=1.0, creativity=1.0, graphics=0.9, sound=0.7}, cost = 12000, yearReq = 1},
    {name = "Relics",         stats = {fun=1.1, creativity=1.1, graphics=1.1, sound=1.0}, cost = 25000, yearReq = 3},
}

-- Compatibility for researched work types and subjects
setCompat("Astronomy Text","Cosmology",5)    setCompat("Astronomy Text","Natural Philosophy",5)
setCompat("Astronomy Text","Creation",4)     setCompat("Astronomy Text","Astronomy",4)
setCompat("Bestiary","Creation",5)           setCompat("Bestiary","Natural Philosophy",4)
setCompat("Bestiary","Herbalism",4)          setCompat("Bestiary","Miracles",3)
setCompat("Bell Casting","Chant",5)          setCompat("Bell Casting","Liturgy",4)
setCompat("Bell Casting","Architecture",4)   setCompat("Bell Casting","Feast Days",3)
setCompat("Metalwork","Architecture",5)      setCompat("Metalwork","Relics",4)
setCompat("Metalwork","Liturgy",3)           setCompat("Metalwork","Angels",3)
setCompat("Herbarium","Herbalism",5)         setCompat("Herbarium","Medicine",5)
setCompat("Herbarium","Natural Philosophy",4)
setCompat("Grand Cathedral","Architecture",5) setCompat("Grand Cathedral","Angels",4)
setCompat("Grand Cathedral","Liturgy",4)     setCompat("Grand Cathedral","Cosmology",3)

setCompat("Manuscript","Apocalypse",4)       setCompat("Manuscript","Miracles",3)
setCompat("Theology","Philosophy",5)         setCompat("Theology","Apocalypse",4)
setCompat("Theology","Angels",3)             setCompat("Theology","Cosmology",4)
setCompat("Sacred Music","Angels",4)         setCompat("Sacred Music","Monasticism",3)
setCompat("Chronicle","Monasticism",4)       setCompat("Chronicle","Relics",4)
setCompat("Prayer Book","Monasticism",4)     setCompat("Prayer Book","Miracles",3)
setCompat("Icon Painting","Angels",5)        setCompat("Icon Painting","Apocalypse",4)
setCompat("Icon Painting","Miracles",4)
setCompat("Herbal Remedy","Agriculture",4)
setCompat("Ale & Mead","Agriculture",5)      setCompat("Ale & Mead","Monasticism",3)
setCompat("Stone Carving","Angels",4)        setCompat("Stone Carving","Relics",4)

-------------------------------------------------------------------------------
-- EVALUATOR NAMES (replaces Reviewer Names)
-------------------------------------------------------------------------------
Data.reviewerNames = {
    "Bishop's Council",
    "Abbey Chronicle",
    "Scholar's Circle",
    "Pilgrim's Report",
}

-------------------------------------------------------------------------------
-- LEVEL UP THRESHOLDS
-------------------------------------------------------------------------------
Data.expThresholds = {
    100, 250, 500, 1000, 2000, 4000, 8000, 16000, 32000, 64000
}

-------------------------------------------------------------------------------
-- EVENT TEMPLATES
-------------------------------------------------------------------------------
Data.events = {
    {name = "Trade Fair",        type = "market",  desc = "A great trade fair boosts commerce!", effect = "salesBoost", amount = 1.3, duration = 8},
    {name = "Famine",            type = "market",  desc = "Famine across the land reduces trade...", effect = "salesBoost", amount = 0.7, duration = 8},
    {name = "Popular Devotion",  type = "trend",   desc = " works are in great demand!", effect = "genreBoost", duration = 12},
    {name = "Divine Inspiration",type = "staff",   desc = " is filled with the Holy Spirit!", effect = "staffBoost", amount = 1.5, duration = 4},
    {name = "Ink Blight",        type = "project", desc = "Bad ink has damaged the current work!", effect = "addBugs", amount = 20},
    {name = "Pilgrims Arrive",   type = "fans",    desc = "Pilgrims flock to your monastery!", effect = "addFans", amount = 10000},
}

return Data
