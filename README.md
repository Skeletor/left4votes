# left4votes
Simplifies custom vote creation process.<br><br>
Usage example:<br>
<code>L4V_CreateVote(OnVoteHandled);
	L4V_SetAllowedTeam(AllowedTeam_Survivors);
	L4V_SetDescription("Fast restart?");
	L4V_SetSuccessDescription("Initiating fast restart...");
	L4V_Start(client);
</code>

<code>void OnVoteHandled(VoteHandledResult res)
{
	if (res == VoteResult_Passed)
		// some action here if vote passes...
}
 </code>
