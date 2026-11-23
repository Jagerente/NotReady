local _, ns = ...

SLASH_NOTREADY1 = "/notready"
SlashCmdList.NOTREADY = function()
    ns.Options.Toggle()
end

function NotReady_OnAddonCompartmentClick()
    ns.Options.Toggle()
end
