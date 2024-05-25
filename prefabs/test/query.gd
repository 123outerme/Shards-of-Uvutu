extends Node

const TEST_DIR: String = 'res://test/'

func _ready():
	create_reports()
	#print_report()

func create_reports():
	var reports: Dictionary = {}
	# add reports one at a time so we can catch and debug errors on a single report easier
	reports['combatants/movepool_report.csv'] = create_report_for_all_combatants_series(
		['Movepool Size', 'Highest Move Lv', 'Highest Lv Move', 'Element Weaknesses', 'Element Resistances', 'Status Resistances', 'Status Immunities'],
		[csv_combatant_movepool_size, csv_combatant_highest_move_lv, csv_combatant_highest_lv_move, csv_combatant_element_weaknesses, csv_combatant_element_resistances, csv_combatant_status_resistances, csv_combatant_status_immunities]
	)
	reports['moves/move_report.csv'] = create_report_for_all_moves_series(
		['Power', 'Element', 'Self Stat Changes', 'Target Stat Changes', 'Status Effect', 'Status Chance'],
		[csv_move_power, csv_move_element, csv_move_self_stat_changes, csv_move_target_stat_changes, csv_move_status, csv_move_status_chance]
	)
	
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		DirAccess.make_dir_recursive_absolute(TEST_DIR)
		
	if not FileAccess.file_exists(TEST_DIR + '.gdignore'):
		var gdIgnoreFile = FileAccess.open(TEST_DIR + '.gdignore', FileAccess.WRITE)
		gdIgnoreFile.close()
	
	for filename: String in reports.keys():
		var subdirs: PackedStringArray = filename.split('/')
		subdirs.remove_at(len(subdirs) - 1) # remove the filename
		var subdir: String = ''
		for subdirPiece in subdirs:
			subdir += subdirPiece + '/'
		#print(subdir)
		
		if not DirAccess.dir_exists_absolute(TEST_DIR + subdir):
			DirAccess.make_dir_recursive_absolute(TEST_DIR + subdir)
		
		var file = FileAccess.open(TEST_DIR + filename, FileAccess.WRITE)
		if file != null:
			file.store_string(reports[filename])
			if file.get_error() != OK:
				printerr('FileAccess error writing CSV content to file ', TEST_DIR + filename, ' (error ', file.get_error(), ')')
			file.close()
		else:
			if FileAccess.get_open_error() != OK:
				printerr('FileAccess error opening file ', TEST_DIR + filename, ' (error ', FileAccess.get_open_error(), ')')

func print_report():
	#for_all_combatants_series([print_combatant_weaknesses, print_combatant_status_resistances])
	#for_all_combatants_series([print_combatant_movepool_size, print_combatant_highest_lv_move])
	#print('\n---\n')
	#for_all_moves(print_move_element)
	#for_all_moves_series([print_move_effects_overview, print_move_role])
	pass

# CSV combatant queries
func create_report_for_all_combatants_series(columns: Array[String], queries: Array[Callable]) -> String:
	if len(columns) != len(queries):
		printerr('Combatants CSV report error: mismatched column and query lengths')
		return ''
	
	var combatantsPath = 'res://gamedata/combatants/'
	var combatantDirs: PackedStringArray = DirAccess.get_directories_at(combatantsPath)
	var reportContents: String = 'Name,'
	for column in columns:
		reportContents += column + ','
	reportContents += '\n'
	
	for dir: String in combatantDirs:
		var combatant: Combatant = Combatant.load_combatant_resource(dir)
		if combatant != null:
			reportContents += combatant.save_name() + ','
			for query in queries:
				var val: String = query.call(combatant)
				reportContents += val + ','
			reportContents += '\n'
			var prevEvolution: Evolution = null
			if combatant.evolutions != null:
				for evolution: Evolution in combatant.evolutions.evolutionList:
					combatant.switch_evolution(evolution, prevEvolution)
					reportContents += evolution.evolutionSaveName + ' (evo ' + combatant.save_name() + '),'
					for query in queries:
						var val: String = query.call(combatant)
						reportContents += val + ','
					reportContents += '\n'
					prevEvolution = evolution
	return reportContents

func csv_combatant_movepool_size(combatant: Combatant) -> String:
	return String.num(len(combatant.stats.movepool.pool))

func csv_combatant_highest_lv_move(combatant: Combatant) -> String:
	var highestLvMove: Move = null
	for move: Move in combatant.stats.movepool.pool:
		if highestLvMove == null or highestLvMove.requiredLv < move.requiredLv:
			highestLvMove = move
	if highestLvMove != null:
		return highestLvMove.moveName
	else:
		return ''

func csv_combatant_highest_move_lv(combatant: Combatant) -> String:
	var highestLvMove: Move = null
	for move: Move in combatant.stats.movepool.pool:
		if highestLvMove == null or highestLvMove.requiredLv < move.requiredLv:
			highestLvMove = move
	if highestLvMove != null:
		return String.num(highestLvMove.requiredLv)
	else:
		return ''

func csv_combatant_element_weaknesses(combatant: Combatant) -> String:
	var weaknesses: String = ''
	var moveEffectiveness: MoveEffectiveness = combatant.get_move_effectiveness()
	for elementIdx in range(len(moveEffectiveness.elementWeaknesses)):
		var element: Move.Element = moveEffectiveness.elementWeaknesses[elementIdx]
		weaknesses += Move.element_to_string(element)
		if elementIdx < len(moveEffectiveness.elementWeaknesses) - 1:
			weaknesses += ' | '
	return weaknesses

func csv_combatant_element_resistances(combatant: Combatant) -> String:
	var resistances: String = ''
	var moveEffectiveness: MoveEffectiveness = combatant.get_move_effectiveness()
	for elementIdx in range(len(moveEffectiveness.elementResistances)):
		var element: Move.Element = moveEffectiveness.elementResistances[elementIdx]
		resistances += Move.element_to_string(element)
		if elementIdx < len(moveEffectiveness.elementResistances) - 1:
			resistances += ' | '
	return resistances

func csv_combatant_status_resistances(combatant: Combatant) -> String:
	var resistances: String = ''
	var moveEffectiveness: MoveEffectiveness = combatant.get_move_effectiveness()
	for statusIdx in range(len(moveEffectiveness.statusResistances)):
		var status: StatusEffect.Type = moveEffectiveness.statusResistances[statusIdx]
		resistances += StatusEffect.status_type_to_string(status)
		if statusIdx < len(moveEffectiveness.statusResistances) - 1:
			resistances += ' | '
	return resistances

func csv_combatant_status_immunities(combatant: Combatant) -> String:
	var immunities: String = ''
	var moveEffectiveness: MoveEffectiveness = combatant.get_move_effectiveness()
	for statusIdx in range(len(moveEffectiveness.statusImmunities)):
		var status: StatusEffect.Type = moveEffectiveness.statusImmunities[statusIdx]
		immunities += StatusEffect.status_type_to_string(status)
		if statusIdx < len(moveEffectiveness.statusImmunities) - 1:
			immunities += ' | '
	return immunities

# CSV move queries
func create_report_for_all_moves_series(columns: Array[String], queries: Array[Callable]) -> String:
	if len(columns) != len(queries):
		printerr('Moves CSV report error: mismatched column and query lengths')
		return ''
	
	var movesPath = 'res://gamedata/moves/'
	var moveDirs: PackedStringArray = DirAccess.get_directories_at(movesPath)
	var reportContents: String = 'Name,Surge?,'
	for column in columns:
		reportContents += column + ','
	reportContents += '\n'
	for dir: String in moveDirs:
		var move: Move = load(movesPath + dir + '/' + dir + '.tres') as Move
		if move != null:
			reportContents += move.moveName + ',Charge,'
			for query in queries:
				var val: String = query.call(move, false)
				reportContents += val + ','
			reportContents += '\n' + move.moveName + ',Surge,'
			for query in queries:
				var val: String = query.call(move, true)
				reportContents += val + ','
			reportContents += '\n'
	return reportContents

func csv_move_element(move: Move, _isSurge: bool) -> String:
	return Move.element_to_string(move.element)

func csv_move_power(move: Move, isSurge: bool) -> String:
	var moveEffect: MoveEffect = move.surgeEffect if isSurge else move.chargeEffect
	return String.num(moveEffect.power)

func csv_move_self_stat_changes(move: Move, isSurge: bool) -> String:
	var moveEffect: MoveEffect = move.surgeEffect if isSurge else move.chargeEffect
	var statMultipliersText: Array[StatMultiplierText] = []
	if moveEffect.selfStatChanges != null and moveEffect.selfStatChanges.has_stat_changes():
		statMultipliersText = moveEffect.selfStatChanges.get_multipliers_text()
	return StatMultiplierText.multiplier_text_list_to_string(statMultipliersText).replace(', ', ' | ')

func csv_move_target_stat_changes(move: Move, isSurge: bool) -> String:
	var moveEffect: MoveEffect = move.surgeEffect if isSurge else move.chargeEffect
	var statMultipliersText: Array[StatMultiplierText] = []
	if moveEffect.targetStatChanges != null and moveEffect.targetStatChanges.has_stat_changes():
		statMultipliersText = moveEffect.targetStatChanges.get_multipliers_text()
	return StatMultiplierText.multiplier_text_list_to_string(statMultipliersText).replace(', ', ' | ')

func csv_move_status(move: Move, isSurge: bool) -> String:
	var moveEffect: MoveEffect = move.surgeEffect if isSurge else move.chargeEffect
	if moveEffect.statusEffect != null:
		var statusDesc: String = StatusEffect.potency_to_string(moveEffect.statusEffect.potency) + ' ' \
				+ moveEffect.statusEffect.get_status_type_string()
		if moveEffect.statusEffect.overwritesOtherStatuses:
			statusDesc += ' | Replaces'
		if moveEffect.selfGetsStatus:
			statusDesc += ' (On Self)'
		return statusDesc
	else:
		return ''

func csv_move_status_chance(move: Move, isSurge: bool) -> String:
	var moveEffect: MoveEffect = move.surgeEffect if isSurge else move.chargeEffect
	if moveEffect.statusChance > 0:
		return String.num(moveEffect.statusChance * 100) + '%'
	else:
		return ''

# Print combatant queries
func for_all_combatants(query: Callable):
	var combatantsPath = 'res://gamedata/combatants/'
	var combatantDirs: PackedStringArray = DirAccess.get_directories_at(combatantsPath)
	for dir: String in combatantDirs:
		var combatant: Combatant = Combatant.load_combatant_resource(dir)
		if combatant != null:
			query.call(combatant)

func for_all_combatants_series(queries: Array[Callable]):
	var combatantsPath = 'res://gamedata/combatants/'
	var combatantDirs: PackedStringArray = DirAccess.get_directories_at(combatantsPath)
	for dir: String in combatantDirs:
		var combatant: Combatant = Combatant.load_combatant_resource(dir)
		if combatant != null:
			for query in queries:
				query.call(combatant)

func print_combatant_weaknesses(combatant: Combatant):
	if combatant.moveEffectiveness == null:
		print(combatant.save_name(), ' has no effectiveness data')
		return
	
	if len(combatant.moveEffectiveness.elementWeaknesses) == 0 and len(combatant.moveEffectiveness.elementResistances) == 0:
		print(combatant.save_name(), ' has no element weaknesses/resistances')
	else:
		if len(combatant.moveEffectiveness.elementWeaknesses) > 0:
			var printStr: String = combatant.save_name() + ' is weak to '
			for weakness: Move.Element in combatant.moveEffectiveness.elementWeaknesses:
				printStr += Move.element_to_string(weakness) + ' '
			print(printStr)
		else:
			print(combatant.save_name(), ' has no element weaknesses')
		if len(combatant.moveEffectiveness.elementResistances) > 0:
			var printStr: String = combatant.save_name() + ' element resists '
			for resistance: Move.Element in combatant.moveEffectiveness.elementResistances:
				printStr += Move.element_to_string(resistance) + ' '
			print(printStr)
		else:
			print(combatant.save_name(), ' has no element resistances')
	if combatant.evolutions != null:
		for evolution: Evolution in combatant.evolutions.evolutionList:
			if evolution.moveEffectiveness == null:
				print(evolution.evolutionSaveName, ' has no effectiveness data')
				continue
			if len(evolution.moveEffectiveness.elementWeaknesses) == 0 and len(evolution.moveEffectiveness.elementResistances) == 0:
				print(evolution.evolutionSaveName, ' has no element weaknesses/resistances')
			else:
				if len(evolution.moveEffectiveness.elementWeaknesses) > 0:
					var printStr = evolution.evolutionSaveName + ' is weak to '
					for weakness: Move.Element in evolution.moveEffectiveness.elementWeaknesses:
						printStr += Move.element_to_string(weakness) + ' '
					print(printStr)
				else:
					print(evolution.evolutionSaveName, ' has no element weaknesses')
				if len(evolution.moveEffectiveness.elementResistances) > 0:
					var printStr = evolution.evolutionSaveName + ' element resists '
					for resistance: Move.Element in evolution.moveEffectiveness.elementResistances:
						printStr += Move.element_to_string(resistance) + ' '
					print(printStr)
				else:
					print(evolution.evolutionSaveName, ' has no element resistances')

func print_combatant_status_resistances(combatant: Combatant):
	if combatant.moveEffectiveness == null:
		print(combatant.save_name(), ' has no effectiveness data')
		return
	
	if len(combatant.moveEffectiveness.statusResistances) == 0 and len(combatant.moveEffectiveness.statusImmunities) == 0:
		print(combatant.save_name(), ' has no status resistances/immunities')
	else:
		if len(combatant.moveEffectiveness.statusResistances) > 0:
			var printStr: String = combatant.save_name() + ' resists '
			for statusType: StatusEffect.Type in combatant.moveEffectiveness.statusResistances:
				printStr += StatusEffect.status_type_to_string(statusType) + ' '
			print(printStr)
		else:
			print(combatant.save_name(), ' has no status resistances')
		if len(combatant.moveEffectiveness.statusImmunities) > 0:
			var printStr: String = combatant.save_name() + ' is immune to '
			for statusType: StatusEffect.Type in combatant.moveEffectiveness.statusImmunities:
				printStr += StatusEffect.status_type_to_string(statusType) + ' '
			print(printStr)
		else:
			print(combatant.save_name(), ' has no status immunities')
	if combatant.evolutions != null:
		for evolution: Evolution in combatant.evolutions.evolutionList:
			if len(evolution.moveEffectiveness.statusResistances) == 0 and len(evolution.moveEffectiveness.statusImmunities) == 0:
				print(evolution.evolutionSaveName, ' has no status resistances/immunities')
			else:
				if len(evolution.moveEffectiveness.statusResistances) > 0:
					var printStr: String = evolution.evolutionSaveName + ' resists '
					for statusType: StatusEffect.Type in evolution.moveEffectiveness.statusResistances:
						printStr += StatusEffect.status_type_to_string(statusType) + ' '
					print(printStr)
				else:
					print(evolution.evolutionSaveName, ' has no status resistances')
				if len(evolution.moveEffectiveness.statusImmunities) > 0:
					var printStr: String = evolution.evolutionSaveName + ' is immune to '
					for statusType: StatusEffect.Type in evolution.moveEffectiveness.statusImmunities:
						printStr += StatusEffect.status_type_to_string(statusType) + ' '
					print(printStr)
				else:
					print(evolution.evolutionSaveName, ' has no status immunities')

func print_combatant_movepool_size(combatant: Combatant):
	print(combatant.save_name(), ' has ', len(combatant.stats.movepool.pool), ' moves')
	if combatant.evolutions != null:
			for evolution: Evolution in combatant.evolutions.evolutionList:
				print(evolution.evolutionSaveName, ' has ', len(evolution.stats.movepool.pool), ' moves')

func print_combatant_highest_lv_move(combatant: Combatant):
	var highestLvMove: Move = null
	for move: Move in combatant.stats.movepool.pool:
		if highestLvMove == null or move.requiredLv > highestLvMove.requiredLv:
			highestLvMove = move
	print(combatant.save_name(), '\'s highest lv move is ', highestLvMove.moveName, ' @ lv ', highestLvMove.requiredLv)
	if combatant.evolutions != null:
			for evolution: Evolution in combatant.evolutions.evolutionList:
				highestLvMove = null
				for move: Move in evolution.stats.movepool.pool:
					if highestLvMove == null or move.requiredLv > highestLvMove.requiredLv:
						highestLvMove = move
				print(evolution.evolutionSaveName, '\'s highest lv move is ', highestLvMove.moveName, ' @ lv ', highestLvMove.requiredLv)

# Print move queries
func for_all_moves(query: Callable):
	var movesPath = 'res://gamedata/moves/'
	var moveDirs: PackedStringArray = DirAccess.get_directories_at(movesPath)
	for dir: String in moveDirs:
		var move: Move = load(movesPath + dir + '/' + dir + '.tres') as Move
		if move != null:
			query.call(move)

func for_all_moves_series(queries: Array[Callable]):
	var movesPath = 'res://gamedata/moves/'
	var moveDirs: PackedStringArray = DirAccess.get_directories_at(movesPath)
	for dir: String in moveDirs:
		var move: Move = load(movesPath + dir + '/' + dir + '.tres') as Move
		if move != null:
			for query in queries:
				query.call(move)

func print_move_element(move: Move):
	print(move.moveName, ' element: ', Move.element_to_string(move.element))

func print_move_role(move: Move):
	print(move.moveName, ' Charge role: ', MoveEffect.role_to_string(move.chargeEffect.role))
	print(move.moveName, ' Surge role: ', MoveEffect.role_to_string(move.surgeEffect.role))

func print_move_effects_overview(move: Move):
	# charge effect
	var printStr: String = move.moveName + ' Charge: ' + String.num(move.chargeEffect.power) \
			+ ' ' + Move.element_to_string(move.element) + ' Power, +' \
			+ String.num(move.chargeEffect.orbChange) + ' Orbs, ' + BattleCommand.targets_to_string(move.chargeEffect.targets)
	
	if move.chargeEffect.selfStatChanges != null and move.chargeEffect.selfStatChanges.has_stat_changes():
		printStr += ', Self StatCh: '
		var statChangesText: Array[StatMultiplierText] = move.chargeEffect.selfStatChanges.get_multipliers_text()
		printStr += StatMultiplierText.multiplier_text_list_to_string(statChangesText)
	
	if move.chargeEffect.targetStatChanges != null and move.chargeEffect.targetStatChanges.has_stat_changes():
		printStr += ', Target StatCh: '
		var statChangesText: Array[StatMultiplierText] = move.chargeEffect.targetStatChanges.get_multipliers_text()
		printStr += StatMultiplierText.multiplier_text_list_to_string(statChangesText)
	
	if move.chargeEffect.statusEffect != null:
		printStr += ', ' + StatusEffect.potency_to_string(move.chargeEffect.statusEffect.potency) + ' ' \
				+ move.chargeEffect.statusEffect.get_status_type_string() + ' (' \
				+ String.num(move.chargeEffect.statusChance * 100) + '%)'
		if move.chargeEffect.selfGetsStatus:
			printStr += ' on self'

	print(printStr)
	
	# surge effect
	printStr = move.moveName + ' Surge: ' + String.num(move.surgeEffect.power) \
			+ ' ' + Move.element_to_string(move.element) + ' Power, ' \
			+ String.num(move.surgeEffect.orbChange) + ' Orbs, ' + BattleCommand.targets_to_string(move.surgeEffect.targets)
	
	if move.surgeEffect.selfStatChanges != null and move.surgeEffect.selfStatChanges.has_stat_changes():
		printStr += ', Self StatCh: '
		var statChangesText: Array[StatMultiplierText] = move.surgeEffect.selfStatChanges.get_multipliers_text()
		printStr += StatMultiplierText.multiplier_text_list_to_string(statChangesText)
	
	if move.surgeEffect.targetStatChanges != null and move.surgeEffect.targetStatChanges.has_stat_changes():
		printStr += ', Target StatCh: '
		var statChangesText: Array[StatMultiplierText] = move.surgeEffect.targetStatChanges.get_multipliers_text()
		printStr += StatMultiplierText.multiplier_text_list_to_string(statChangesText)
	
	if move.surgeEffect.statusEffect != null:
		printStr += ', ' + StatusEffect.potency_to_string(move.surgeEffect.statusEffect.potency) + ' ' \
				+ move.surgeEffect.statusEffect.get_status_type_string() + ' (' \
				+ String.num(move.surgeEffect.statusChance * 100) + '%)'
		if move.surgeEffect.selfGetsStatus:
			printStr += ' on self'

	print(printStr)
