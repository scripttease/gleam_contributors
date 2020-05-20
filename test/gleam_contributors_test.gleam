import gleam_contributors.{Sponsorspage}
import gleam/should


pub fn hello_world_test() {
  gleam_contributors.hello_world()
  |> should.equal("Hello, from gleam_contributors!")
}

pub fn parse_empty_with_cursor_test() {
  let json = "
 {
  \"data\": {
    \"user\": {
      \"sponsorshipsAsMaintainer\": {
        \"pageInfo\": {
          \"hasNextPage\": false,
          \"endCursor\": \"MjE\"
        },
        \"nodes\": [] }
      }
    }
  }

  "
  gleam_contributors.parse(json)
  |> should.equal(Ok(Sponsorspage(nextpage_cursor: Error(Nil))))
}


pub fn parse_test() {
  let json = "
 {
  \"data\": {
    \"user\": {
      \"sponsorshipsAsMaintainer\": {
        \"pageInfo\": {
          \"hasNextPage\": true,
          \"endCursor\": \"MjE\"
        },
        \"nodes\": [
          {
            \"sponsorEntity\": {
              \"name\": \"Bruno Michel\",
              \"avatarUrl\": \"https://avatars3.githubusercontent.com/u/2767?u=ff72b1ad63026e0729acc2dd41378e28ab704a3f&v=4\",
              \"websiteUrl\": \"http://blog.menfin.info/\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"José Valim\",
              \"avatarUrl\": \"https://avatars0.githubusercontent.com/u/9582?u=aa5911734b48eed403a69217a2f233d33af87836&v=4\",
              \"websiteUrl\": \"https://dashbit.co/\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Keith\",
              \"avatarUrl\": \"https://avatars3.githubusercontent.com/u/28033?u=e24fcb89b8e2e290e4a06af97e7d6d10572a23d7&v=4\",
              \"websiteUrl\": null
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Erik Terpstra\",
              \"avatarUrl\": \"https://avatars3.githubusercontent.com/u/39518?v=4\",
              \"websiteUrl\": \"https://www.linkedin.com/in/eterps/\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Arno Dirlam\",
              \"avatarUrl\": \"https://avatars2.githubusercontent.com/u/43364?u=cbfab3a095d5b838e74934e3df03627bc16bc827&v=4\",
              \"websiteUrl\": \"twitter.com/arnodirlam\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Parker Selbert\",
              \"avatarUrl\": \"https://avatars2.githubusercontent.com/u/270831?v=4\",
              \"websiteUrl\": \"sorentwo.com\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Quinn Wilton\",
              \"avatarUrl\": \"https://avatars0.githubusercontent.com/u/285821?u=7cb734336845de0741fe0cfb93d54785faee8334&v=4\",
              \"websiteUrl\": \"http://quinnwilton.com\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"John Palgut\",
              \"avatarUrl\": \"https://avatars2.githubusercontent.com/u/455046?u=0092bfecadfc3aac5e1df3145ea4e0a55a896787&v=4\",
              \"websiteUrl\": \"http://jwsonic.github.io\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Bruno Dusausoy\",
              \"avatarUrl\": \"https://avatars3.githubusercontent.com/u/533326?v=4\",
              \"websiteUrl\": \"http://blog.codinsanity.be\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Christian Wesselhoeft\",
              \"avatarUrl\": \"https://avatars1.githubusercontent.com/u/602654?u=77600b168d2517580980666885192e57165df452&v=4\",
              \"websiteUrl\": \"https://xtian.us\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Sasan Hezarkhani\",
              \"avatarUrl\": \"https://avatars1.githubusercontent.com/u/972202?u=d9dd20f0d1e6a8a2f2b027c1bcce964be682093b&v=4\",
              \"websiteUrl\": \"https://medium.com/@gootik/\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Sebastian Porto\",
              \"avatarUrl\": \"https://avatars1.githubusercontent.com/u/1005498?v=4\",
              \"websiteUrl\": null
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Hasan YILDIZ\",
              \"avatarUrl\": \"https://avatars3.githubusercontent.com/u/1096278?u=cc76b3a88b72a4e13d83bf8c2b7281e2c4ec7128&v=4\",
              \"websiteUrl\": \"http://www.hsnyildiz.com\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Chris Young\",
              \"avatarUrl\": \"https://avatars1.githubusercontent.com/u/1434500?u=63d292348087dba0ba6ac6549c175d04b38a46c9&v=4\",
              \"websiteUrl\": null
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Lars Wikman\",
              \"avatarUrl\": \"https://avatars0.githubusercontent.com/u/1971237?u=222ac5ebb788ceb72ce71e00f8a807e176485a56&v=4\",
              \"websiteUrl\": \"http://underjord.io\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"iRedMail\",
              \"avatarUrl\": \"https://avatars1.githubusercontent.com/u/2048991?u=32ed41e515b63cd5e47327f51d1672271ef8dfc3&v=4\",
              \"websiteUrl\": \"https://www.iredmail.org/\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Arian Daneshvar\",
              \"avatarUrl\": \"https://avatars2.githubusercontent.com/u/2433008?u=2e3dc40cae57ced745de8154974c8777e786c628&v=4\",
              \"websiteUrl\": null
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Sascha Wolf\",
              \"avatarUrl\": \"https://avatars3.githubusercontent.com/u/2647626?u=fdd5e33d752c02a13d0a0de36906ff452b71e802&v=4\",
              \"websiteUrl\": \"https://saschawolf.me\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"ontofractal\",
              \"avatarUrl\": \"https://avatars2.githubusercontent.com/u/4211840?u=97aeb67208068d457fad522a500b62f12908270c&v=4\",
              \"websiteUrl\": \"https://twitter.com/ontofractal\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Tyler Wilcock\",
              \"avatarUrl\": \"https://avatars0.githubusercontent.com/u/6610100?u=f373f811042bdbb449801cfcf80e222076e7d9a8&v=4\",
              \"websiteUrl\": \"https://twilco.github.io\"
            },
            \"tier\": null
          },
          {
            \"sponsorEntity\": {
              \"name\": \"Bryan Paxton\",
              \"avatarUrl\": \"https://avatars0.githubusercontent.com/u/39971740?u=f234e6106097a35c95d4c6e4696ed966c09cac18&v=4\",
              \"websiteUrl\": null
            },
            \"tier\": null
          }
        ]
      }
    }
  }
} 
  "
  gleam_contributors.parse(json)
  |> should.equal(Ok(Sponsorspage(nextpage_cursor: Ok("MjE"))))
}