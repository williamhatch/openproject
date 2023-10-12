// -- copyright
// OpenProject is an open source project management software.
// Copyright (C) 2012-2023 the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { ChangeDetectionStrategy, Component, EventEmitter, forwardRef, Input, OnInit, Output } from '@angular/core';
import { Observable } from 'rxjs';
import { filter, map } from 'rxjs/operators';
import { ControlValueAccessor, NG_VALUE_ACCESSOR } from '@angular/forms';
import { ID } from '@datorama/akita';
import { OpInviteUserModalService } from 'core-app/features/invite-user-modal/invite-user-modal.service';
import { HalResource } from 'core-app/features/hal/resources/hal-resource';
import {
  OpAutocompleterBaseDirective,
} from "core-app/shared/components/autocompleter/op-autocompleter/op-autocompleter-base.directive";
import { InjectField } from "core-app/shared/helpers/angular/inject-field.decorator";
import { IHALCollection } from "core-app/core/apiv3/types/hal-collection.type";

export const usersAutocompleterSelector = 'op-user-autocompleter';

export interface IUserAutocompleteItem {
  id:ID;
  name:string;
  href:string|null;
  avatar:string|null;
}

@Component({
  templateUrl: './user-autocompleter.component.html',
  selector: usersAutocompleterSelector,
  changeDetection: ChangeDetectionStrategy.OnPush,
  providers: [
    {
      provide: NG_VALUE_ACCESSOR,
      useExisting: forwardRef(() => UserAutocompleterComponent),
      multi: true,
    },
    // Provide a new version of the modal invite service,
    // as otherwise the close event will be shared across all instances
    OpInviteUserModalService,
  ],
})
export class UserAutocompleterComponent
  extends OpAutocompleterBaseDirective<IUserAutocompleteItem>
  implements OnInit, ControlValueAccessor {
  userTracker = (item:{ href?:string, id:string }):string => item.href || item.id;

  @Input() public inviteUserToProject:string|undefined;

  @Output() public userInvited = new EventEmitter<HalResource>();

  @InjectField(OpInviteUserModalService) opInviteUserModalService:OpInviteUserModalService;

  ngOnInit():void {
    this
      .opInviteUserModalService
      .close
      .pipe(
        this.untilDestroyed(),
        filter((user) => !!user),
      )
      .subscribe((user:HalResource) => {
        this.userInvited.emit(user);
      });
  }

  public getAvailableUsers(searchTerm?:string):Observable<IUserAutocompleteItem[]> {
    const filteredURL = this.buildFilteredURL(searchTerm);

    filteredURL.searchParams.set('pageSize', '-1');
    filteredURL.searchParams.set('select', 'elements/id,elements/name,elements/href,elements/avatar,total,count,pageSize');

    return this
      .http
      .get<IHALCollection<IUserAutocompleteItem>>(filteredURL.toString())
      .pipe(
        map((res) => res._embedded.elements),
      );
  }

  protected defaultUrl():string {
    return this.apiV3Service.users.path;
  }
}
