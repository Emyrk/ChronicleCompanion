if not SetAutoloot then

	StaticPopupDialogs["NO_SUPERWOW_CHRONICLE"] = {
		text = "|cffffff00Chronicle|r requires SuperWoW to operate.",
		button1 = TEXT(OKAY),
		timeout = 0,
		whileDead = 1,
		hideOnEscape = 1,
		showAlert = 1,
	}

	StaticPopup_Show("NO_SUPERWOW_CHRONICLE")
	return
end

