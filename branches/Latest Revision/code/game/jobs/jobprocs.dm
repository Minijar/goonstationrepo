/proc/SetupOccupationsList()
	var/list/new_occupations = list()

	for(var/occupation in occupations)
		if (!(new_occupations.Find(occupation)))
			new_occupations[occupation] = 1
		else
			new_occupations[occupation] += 1

	occupations = new_occupations
	return

/proc/FindOccupationCandidates(list/unassigned, job, level)
	var/list/candidates = list()

	for (var/mob/human/M in unassigned)
		if (level == 1 && M.occupation1 == job)
			candidates += M

		if (level == 2 && M.occupation2 == job)
			candidates += M

		if (level == 3 && M.occupation3 == job)
			candidates += M

	return candidates

/proc/PickOccupationCandidate(list/candidates)
	if (candidates.len > 0)
		var/list/randomcandidates = shuffle(candidates)
		candidates -= randomcandidates[1]
		return randomcandidates[1]

	return null

/proc/DivideOccupations()
	var/list/unassigned = list()
	var/list/occupation_choices = occupations.Copy()
	var/list/occupation_eligible = occupations.Copy()
	occupation_choices = shuffle(occupation_choices)

	for (var/mob/human/M in world)
		if (M.client && M.start && !M.already_placed)
			unassigned += M

			// If someone picked AI before it was disabled, or has a saved profile with it
			// on a game that now lacks it, this will make sure they don't become the AI,
			// by changing that choice to Captain.
			if (!config.allow_ai)
				if (M.occupation1 == "AI")
					M.occupation1 = "Captain"
				if (M.occupation2 == "AI")
					M.occupation2 = "Captain"
				if (M.occupation3 == "AI")
					M.occupation3 = "Captain"

	if (unassigned.len == 0)
		return

	var/mob/human/captain_choice = null
//	var/mob/human/ai_choice = null

	for (var/level = 1 to 3)
		var/list/captains = FindOccupationCandidates(unassigned, "Captain", level)
//		var/list/ais = FindOccupationCandidates(unassigned, "AI", level)
		var/mob/human/candidate = PickOccupationCandidate(captains)
//		var/mob/ai/candidate2 = PickOccupationCandidate(ais)

		if (candidate != null)
			captain_choice = candidate
//			ai_choice = candidate2
			unassigned -= captain_choice
//			unassigned -= ai_choice
			break

	if (captain_choice == null && unassigned.len > 1)
		unassigned = shuffle(unassigned)
		captain_choice = unassigned[1]
		unassigned -= captain_choice

//	if (ai_choice == null && ticker.mode.name == "AI malfunction" && unassigned.len > 1)
//		unassigned = shuffle(unassigned)
//		ai_choice = unassigned[1]
//		unassigned -= ai_choice

	if (captain_choice == null)
		world << text("Captainship not forced on someone since this is a one-player game.")
	else
		captain_choice.Assign_Rank("Captain")

//	if (ai_choice != null)
//		ai_choice.Assign_Rank("AI")

	for (var/level = 1 to 3)
		if (unassigned.len == 0)
			break

		for (var/occupation in assistant_occupations)
			if (unassigned.len == 0)
				break
			var/list/candidates = FindOccupationCandidates(unassigned, occupation, level)
			for (var/mob/human/candidate in candidates)
				candidate.Assign_Rank(occupation)
				unassigned -= candidate

		for (var/occupation in occupation_choices)
			if (unassigned.len == 0)
				break
			var/eligible = occupation_eligible[occupation]
			if (eligible == 0)
				continue
			var/list/candidates = FindOccupationCandidates(unassigned, occupation, level)
			var/eligiblechange = 0
			//world << text("occupation [], level [] - [] eligible - [] candidates", level, occupation, eligible, candidates.len)
			while (eligible--)
				var/mob/human/candidate = PickOccupationCandidate(candidates)
				if (candidate == null)
					break
				//world << text("candidate []", candidate)
				candidate.Assign_Rank(occupation)
				unassigned -= candidate
				eligiblechange++
			occupation_eligible[occupation] -= eligiblechange

	if (unassigned.len)
		unassigned = shuffle(unassigned)
		for (var/occupation in occupation_choices)
			if (unassigned.len == 0)
				break
			var/eligible = occupation_eligible[occupation]
			while (eligible-- && unassigned.len > 0)
				var/mob/human/candidate = unassigned[1]
				if (candidate == null)
					break
				candidate.Assign_Rank(occupation)
				unassigned -= candidate

	for (var/mob/human/M in unassigned)
		M.Assign_Rank(pick(assistant_occupations))

	for (var/mob/ai/aiPlayer in world)
		spawn(0)
			var/randomname = pick(ai_names)
			var/newname = input(
				aiPlayer,
				"You are the AI. Would you like to change your name to something else?", "Name change",
				randomname)

			if (length(newname) == 0)
				newname = randomname

			if (newname)
				if (length(newname) >= 26)
					newname = copytext(newname, 1, 26)
				newname = dd_replacetext(newname, ">", "'")
				aiPlayer.rname = newname
				aiPlayer.name = newname

			world << text("<b>[] is the AI!</b>", aiPlayer.rname)

	for(var/turf/space/sp in world)
		if (sp.updatecell && sp.z != 1 && sp.z != 4)
			sp.updatecell = 0 //Remind me to move this somewhere else after testing.

	return
