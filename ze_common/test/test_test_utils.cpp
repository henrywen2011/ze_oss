// Copyright (C) ETH Zurich, Wyss Zurich, Zurich Eye - All Rights Reserved
// Unauthorized copying of this file, via any medium is strictly prohibited
// Proprietary and confidential

#include <cmath>

#include <ze/common/test_entrypoint.hpp>
#include <ze/common/test_utils.hpp>

TEST(TestUtilsTest, testTestData)
{
  EXPECT_NO_FATAL_FAILURE(ze::getTestDataDir("synthetic_room_pinhole"));
}

TEST(TestUtilsTest, testLoadCsvPoses)
{
  using namespace ze;

  std::string data_path = getTestDataDir("synthetic_room_pinhole");
  std::string filename = data_path + "/traj_gt.csv";
  std::map<int64_t, Transformation> poses = loadIndexedPosesFromCsv(filename);
  EXPECT_EQ(poses.size(), 50u);
  EXPECT_FLOATTYPE_EQ(poses[1].getPosition().x(), real_t{1.499260});
}

ZE_UNITTEST_ENTRYPOINT