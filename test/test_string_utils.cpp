#include <string>
#include <vector>

#include <ze/common/string_utils.h>
#include <ze/common/test/entrypoint.h>


TEST(StringUtilsTest, testTrim)
{
  std::string a = " abc ";
  a = ze::common::trimString(a);
  EXPECT_EQ(a, "abc");
}

TEST(StringUtilsTest, testSplit)
{
  std::string a = "one,two,three";
  std::vector<std::string> vec = ze::common::splitString(a, ',');
  EXPECT_EQ(vec.size(), 3u);
  EXPECT_EQ(vec[0], "one");
  EXPECT_EQ(vec[1], "two");
  EXPECT_EQ(vec[2], "three");
}

ZE_UNITTEST_ENTRYPOINT
