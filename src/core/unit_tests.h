/*
 * Copyright (c) 2012-2021 Daniele Bartolini et al.
 * License: https://github.com/dbartolini/crown/blob/master/LICENSE
 */

#pragma once

namespace crown
{
	/// Runs all the unit tests.
	int main_unit_tests();

	///
	int main_send(const char* json, u16 port);

} // namespace crown
