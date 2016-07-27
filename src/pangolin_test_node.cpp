#include <ze/pangolin/pangolin.hpp>
#include <ze/pangolin/type_watches.hpp>
#include <ze/pangolin/pangolin_insight.hpp>

class Sample
{
public:
  void increment() { ++value; }
private:
  //int value;
  PANGOLIN_WATCH(int, value);
};

int main( int /*argc*/, char* argv[] )
{
//  PANGOLIN_WATCH(int, test);

//  int x = 2;

//  test = x;

//  while(true)
//  {
//    test += 0.3;
//    sleep(1u);
//  }

  std::shared_ptr<Sample> sample(std::make_shared<Sample>());

  while(true)
  {
    sample->increment();
    sleep(1u);
  }

  return 0;
}
